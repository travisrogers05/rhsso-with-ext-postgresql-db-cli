# Using the JBoss CLI to configure an external Postgresql database with Red Hat SSO for Openshift

Example of configuring and using an external Postgresql database with the Red Hat Single Sign On (SSO) container for Openshift.

This example does not add a Postgresql JDBC driver as the Red Hat SSO image currently provides a version of the Postgresql JDBC driver.  Please be aware that this could change in future versions of the RHSSO image where third party JDBC drivers might not be provided and would need to be installed.  A datasource is created at deploy time that uses the Postgresql JDBC driver.  This example assumes that the Postgresql database is visible to pods via DNS alone.

**NOTE:** This example requires that specifics for the Posgresql database be provided.  Look at the [actions.cli](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/extensions/actions.cli) file for database specific settings.

This repository provides a working reference which includes:

- An `.s2i` directory that includes an `environment` [file](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/.s2i/environment) that sets `CUSTOM_INSTALL_DIRECTORIES=extensions`.  This is used by scripts provided in the Red Hat SSO image to allow for customization to take place at pod deploy time.
- An `extensions` directory that includes
  - a [install.sh](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/extensions/install.sh) file that copies required files/scripts into the container.
  - a [postconfigure.sh](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/extensions/postconfigure.sh) file that executes a JBoss cli batch file.
  - a JBoss cli batch file [actions.cli](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/extensions/actions.cli) that creates and configures the Postgresql datasource
- A [template file](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/sso72-https-ext-postgresql-cli.json) that is derived from an [example template](https://github.com/jboss-openshift/application-templates/blob/ose-v1.4.13/sso/sso72-https.json) provided by Red Hat.  The template is [set to use](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/sso72-https-ext-postgresql-cli.json#L376-#L384) the [RHSSO 7.2 imagestream](https://access.redhat.com/containers/#/registry.access.redhat.com/redhat-sso-7/sso72-openshift).  
- The template contains the following modifications: 
  - Added a [buildconfig](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/sso72-https-ext-postgresql-cli.json#L356-#L413) to allow the inclusion of files from this git repo into the image.
  - Added an [imagestream definition](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/sso72-https-ext-postgresql-cli.json#L346-#L355) for the resulting RHSSO container that we are creating.
  - Added [parameters](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/sso72-https-ext-postgresql-cli.json#L45-#L65) for building from a git repository


## How it works

The modified template [sso72-https-ext-postgresql-cli.json](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/sso72-https-ext-postgresql-cli.json) is used to introduce a buildconfig that will incorporate files contained within a Git repository.  The default repository is [this repo](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli).  The build process clones this git repository into a build pod that performs a build of the RHSSO container.  The Openshift build process produces a container image to be used for an RHSSO pod.

When the resulting container image is used to produce an RHSSO pod, the pod is configured at deploy time to include datasource settings provided by the [actions.cli](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/extensions/actions.cli).  During the deployment phase, the [postconfigure.sh](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/extensions/postconfigure.sh) executes the [actions.cli](https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli/blob/master/extensions/actions.cli) file in turn configuring the RHSSO based container to include a Postgresql datasource representing the external database.


## Requirements
- [Openshift command line client (oc)](https://www.okd.io/download.html)
- Openssl
- Java keytool


## Steps to use this example

- Create a project and a serviceaccount.  Then add visibility for the system servieaccount.

~~~
oc new-project rhsso-ext-postgres-cli
oc create serviceaccount sso-service-account
oc policy add-role-to-user view system:serviceaccount:$(oc project -q):sso-service-account
~~~

- Create the template in your project namespace or in the openshift namespace, should you wish for the template to be viewable by other users/developers.
~~~
oc create -f sso72-https-ext-postgresql-cli.json -n rhsso-ext-postgres-cli
~~~

- Create (or supply existing) certs and trust stores for encrypted communication.  I have a script for this, so you will see environment variables being referenced.  This is just for reference as you likely have your own certs and trust stores to use.  Use the appropriate values when creating the RHSSO pod in a later step.  You can find out more about these steps in the [RHSSO documentation](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.3/html-single/red_hat_single_sign-on_for_openshift/#advanced-concepts-Configuring-Keystores).

  - Create CA key and cert
  ~~~
  openssl req -new -newkey rsa:4096 -x509 -keyout $CAKEY -out $CACERT -days 365 -subj "/CN=xpaas-sso-demo.ca" -passin pass:$CAPASS -passout pass:$CAPASS
  ~~~

  - Create HTTPS keystore
  ~~~
  keytool -genkeypair -keyalg RSA -keysize 2048 -dname "CN=$HOSTNAME_HTTPS" -alias $HTTPS_NAME -keystore $HTTPS_KEYSTORE -keypass $HTTPS_PASSWORD -storepass $HTTPS_PASSWORD
  ~~~

  - Create HTTPS cert request
  ~~~
  keytool -certreq -keyalg rsa -alias $HTTPS_NAME -keystore $HTTPS_KEYSTORE -file $SSOSIGNREQ -keypass $HTTPS_PASSWORD -storepass $HTTPS_PASSWORD
  ~~~

  - Create SSO cert
  ~~~
  openssl x509 -trustout -req -CA $CACERT -CAkey $CAKEY -in $SSOSIGNREQ -out $SSOCERT -days 365 -CAcreateserial -passin pass:$CAPASS
  ~~~

  - Add CA cert to HTTPS keystore
  ~~~
  keytool -import -noprompt -trustcacerts -file $CACERT -alias $CAALIAS -keystore $HTTPS_KEYSTORE -keypass $HTTPS_PASSWORD -storepass $HTTPS_PASSWORD
  ~~~

  - Add SSO cert to HTTPS keystore
  ~~~
  keytool -import -noprompt -trustcacerts -file $SSOCERT -alias $HTTPS_NAME -keystore $HTTPS_KEYSTORE -keypass $HTTPS_PASSWORD -storepass $HTTPS_PASSWORD
  ~~~

  - Add CA cert to SSO truststore
  ~~~
  keytool -import -noprompt -trustcacerts -file $CACERT -alias $CAALIAS -keystore $SSO_TRUSTSTORE -keypass $CAPASS -storepass $CAPASS
  ~~~

  - Create JGROUPS keystore
  ~~~
  keytool -genseckey -alias $JGROUPS_ENCRYPT_NAME -storetype JCEKS -keypass $JGROUPS_ENCRYPT_PASSWORD -storepass $JGROUPS_ENCRYPT_PASSWORD -keystore $JGROUPS_ENCRYPT_KEYSTORE
  ~~~


- Create one secret for all stores

~~~
oc create secret generic $HTTPS_SECRET --from-file=$JGROUPS_ENCRYPT_KEYSTORE --from-file=$HTTPS_KEYSTORE --from-file=$SSO_TRUSTSTORE
oc secret add sa/sso-service-account secret/$HTTPS_SECRET
~~~

- Create the RHSSO pod passing in some parameters that you may want to specifically set.
~~~
oc process openshift//sso72-https-ext-postgresql-cli \
-p APPLICATION_NAME=rhsso-ext-postgres-cli-app \
-p IMAGE_STREAM_NAMESPACE=openshift \
-p SOURCE_REPOSITORY_URL=https://github.com/travisrogers05/rhsso-with-ext-postgresql-db-cli \
-p SOURCE_REPOSITORY_REF=master \
-p HOSTNAME_HTTP=rhsso-ext-postgres-cli-app-rhsso-ext-postgres-cli.example.com \
-p HOSTNAME_HTTPS=secure-rhsso-ext-postgres-cli-app-rhsso-ext-postgres-cli.example.com \
-p HTTPS_KEYSTORE=sso-https.jks \
-p HTTPS_KEYSTORE_TYPE=jks \
-p HTTPS_NAME=sso-https-key \
-p HTTPS_PASSWORD=password \
-p JGROUPS_ENCRYPT_SECRET=sso-app-secret \
-p JGROUPS_ENCRYPT_KEYSTORE=jgroups.jceks \
-p JGROUPS_ENCRYPT_NAME=jgroups \
-p JGROUPS_ENCRYPT_PASSWORD=password \
-p SSO_ADMIN_USERNAME=admin \
-p SSO_ADMIN_PASSWORD=admin \
-p SSO_REALM=demo \
-p SSO_TRUSTSTORE=truststore.jks \
-p SSO_TRUSTSTORE_PASSWORD=password \
-p SSO_TRUSTSTORE_SECRET=sso-app-secret \
| oc create -f -
~~~

At this point you should see a build process initiate followed by a deployment of the RHSSO pod.

# concourse-deploy-cloudfoundry

Deploy Cloud Foundry with [omg](https://github.com/enaml-ops) in a Concourse pipeline.

## Prerequisites

1. [Git](https://git-scm.com)
1. [Vault](https://www.vaultproject.io)
1. [Concourse](http://concourse.ci)

## Steps to use this pipeline

1. Clone this repository.

    ```
    git clone https://github.com/enaml-ops/concourse-deploy-cloudfoundry.git
    ```

1. Copy the sample config file `vault-ip-sample.json`.

    ```
    cd concourse-deploy-cloudfoundry
    cp vault-ip-sample.json vault-ip.json
    ```

1. Edit `vault-ip.json`, adding the appropriate values.

    ```
    $EDITOR vault-ip.json
    ```

    All available keys can be listed by querying the plugin.  If not specified in `vault-ip.json`, default values will be used where possible.

    ```
    omg-linux deploy-product cloudfoundry-plugin-linux --help
    ```

1. Load the key/value pairs into `vault`:

    ```
    VAULT_ADDR=http://YOUR_VAULT_ADDR:8200
    VAULT_HASH=secret/cf-staging-ips
    vault write ${VAULT_HASH} @vault-ip.json
    ```

1. Delete or move `vault-ip.json` to a secure location.
1. Copy the credentials template.

    ```
    cp ci/credentials-template.yml credentials.yml
    ```

1. Edit `credentials.yml`, adding appropriate values.

    ```
    $EDITOR credentials.yml
    ```

    Note: If you are deploying Pivotal CF (PCF), you must add your `API Token` found at the bottom of your [Pivotal Profile](https://network.pivotal.io/users/dashboard/edit-profile) page.

1. Create or update the pipeline.

    ```
    fly -t TARGET set-pipeline -p deploy-cloudfoundry -c ci/deploy-cloudfoundry.yml -l vault-ip.json
    ```

1. Delete or move `credentials.yml` to a secure location.
1. Unpause the pipeline

    ```
    fly -t TARGET unpause-pipeline -p deploy-cloudfoundry
    ```

1. Trigger the deployment job and observe the output.

    ```
    fly -t TARGET trigger-job -j deploy-cloudfoundry/deploy -w
    ```



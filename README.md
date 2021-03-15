# iam-users-gcc

Creates iam user with GCC permission boundary attached automatically

## Usage

```hcl
module 'iam-user-gcc' {
  name = "My Name"

  # official work email
  mail = "my_email@tech.gov.sg"

  # create with `gpg --full-generate-key`, list with `gpg --list-secret-keys --keyid-format LONG` and get with `gpg --export %KEY_ID% | base64 -w 0`
  pgp_key = "mQINBF6qL/IdKGMQawxsCwUvm3Y4yjhC+WzAP7U7o48IMv0Zi0ichuvtTMJwsTLc6ym4fuBrYquzlu92PvDHb2EZKJNA9kW8t4mNQsVFtU6HQfpnnABSVed+eFBEQjBl89Jj9TlYBRBVqH0QYtPyUmrJcWxfbD7N3yQUPtJ8TLFSda+E/vG146a08eZsoKxMzb3dDCLf7nJ+epwmvIdspiI+/+fNNn7jqJC9RksL8OXrV9w+qN3u7Budxni/ZIecaenBFAs9IRn+4rfplvVlPyXLlb6w=="

  # add a reason for why this account needs to exist
  purpose = "devops usage"

  # Username in IAM users
  username = "my_name_cli"

}
```

## Prerequisites

This module assumes you, and the users that you are helping to create access tokens for have knowledge of aws cli, otherwise please read [aws cli docs](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html) prior to this so as to familiarise yourself with the various commands

## Access token
### Generating your GPG key

Expected output: **Base64-encoded, non-ASCII-armored GPG public key**

1. Check if you have any existing GPG keys using `gpg --list-secret-keys --keyid-format LONG`
2. IF you don't have any, create one using `gpg --full-gen-key`
    1. Select **(1) RSA and RSA (default)**
    2. Enter a keysize of **4096**
    3. Enter a key validity of **1y** (1 year)
    4. Enter your **real name** when asked for it
    5. Enter your **official work email address** when asked for it
    6. Enter in a comment if you want
    7. Verify the **USER-ID** reflected back to you is correct (eg. `"joseph_testing_20200427 (no comments)  <joseph_testing_20200427@gmail.com>"`)
    8. Use **O** to indicate okay
    9. Enter in a key password and enter it in again to verify it
    10. Generate the random bytes the `gpg` program needs by surfing the web (if needed)
    11. You should see a key signature with `pub`, `uid`, and `sub` in the first column
3. If you completed step 2, run step 1 again and find the key you wish to use. The ID of they is on the same line as the row of information starting with **`sec   rsaXXXX/%KEY_ID% YYYY-MM-DD [SC] ....`**. Extract the `%KEY_ID%`.
4. Export your selected key by running:
    1. On Linux: `gpg --export %KEY_ID% | base64 -w 0`
    2. On MacOS: `gpg --export %KEY_ID% | base64 -b 0`
5. Pass this base64-encoded public key to the operations fella

### Receiving your access keys

You will need the following information to proceed:

* `AWS_ACCOUNT_ID`
* `ACCESS_KEY_ID`
* `ENCRYPTED_SECRET_ACCESS_KEY`
* `AWS_USER` - Most likely your username, e.g xxx_cli
* `ROLE` - Retrieve this from your admin, e.g developer, great-power
* `ROLE_ARN`: `arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE}`
* `MFA_SERIAL`: `arn:aws:iam::${AWS_ACCOUNT_ID}:mfa/${AWS_USER}`

1. The secret access key you will receive is base64-encoded and encrypted with your public key. To decrypt it, run `echo ${ENCRYPTED_SECRET_ACCESS_KEY} | base64 -d > ./aws_secret_access_key.enc`
2. Decrypt the file by running `gpg --decrypt ./aws_secret_access_key.enc > ./aws_secret_access_key`
3. Create a file at `~/.aws/credentials` if you don't already have it and paste in the following, making the appropriate substitutions:
    1. ${PROFILE} is a profile name of your choice, e.g my-project-environment
    2. `${SECRET_ACCESS_KEY}` with the decrypted key from step 2.
    ```ini
    [${PROFILE}]
    aws_access_key_id = ${ACCESS_KEY_ID}
    aws_secret_access_key = ${SECRET_ACCESS_KEY} #disclaimer: PLEASE DO NOT PASTE THIS VALUE TO ANYONE AS THIS IS YOUR PASSWORD
    ```

### Creating your virtual MFA

Before we assume a role, you'll need to create a virtual MFA via the [AWS CLI tool](https://aws.amazon.com/cli/) on your local machine. This is because we have enabled MFA for all user access tokens on the group level, if your policy does not require MFA, you may skip this step.

1. Install the [AWS CLI tool](https://aws.amazon.com/cli/).
2. Set the AWS cli to use the profile you defined above: `export AWS_PROFILE=${PROFILE}`
3. Run the following your terminal to create the virtual MFA:
    ```sh
    aws iam create-virtual-mfa-device --virtual-mfa-device-name ${AWS_USER} --outfile ~/mfa_${AWS_USER}.png --bootstrap-method QRCodePNG;
    ```
4. Open the file at `~/mfa_${AWS_USER}.png` and scan it with your authenticator application, note two consecutive codes it generates.
5. Run the following in your terminal to enable the virtual MFA (replace `000000` and `111111` with the two generated codes):
    ```sh
    aws iam enable-mfa-device --user-name ${AWS_USER} --serial-number ${MFA_SERIAL} --authentication-code1 000000 --authentication-code2 111111
    ```

*Note* `MFA_SERIAL` is arn:aws:iam::${ACCOUNT_ID}:mfa/${AWS_USER}


### Configuring AWS cli to assume roles

To access roles you are granted, you'll need to assume an IAM Role. IAM Roles which you can assume are based on the IAM Groups you are in, and the IAM Roles affect your permissions on the various AWS resources.

#### Easier method

Run the below script to create a new profile under `~/.aws/credentials` with the postfix `-temp` of your current `AWS_PROFILE`.

The following environment variables should be set in your shell environment prior to running the script. To make it easier and not have to retype these variables everytime, consider installing a tool such as [direnv](https://direnv.net/). This is considered easier because there is less configuration required on `~/.aws/config` and `~/.aws/credentials` which is error prone especially for first time users.

| Name            | Description                                                                           |
| --------------- | ------------------------------------------------------------------------------------- |
| AWS_PROFILE_CLI | Profile to use, reference from ~/.aws/credentials`                                    |
| ACCOUNT_ID      | The AWS account id                                                                    |
| AWS_USERNAME    | Your username as referenced from IAM console, e.g my_name_cli                         |
| IAM_ROLE        | The role you are trying to assume to get permissions from, e.g developer, great-power |

The created `-temp` profile should be used, meaning you run `export AWS_PROFILE=xxx-temp` before running any aws cli commands.

```sh
#!/bin/bash
# auth.sh

set -e
if [ -z "$1" ]; then
  echo "Need MFA..."
  exit 1;
fi

function assrole() {
  PROFILE_NAME=$1
  ACCOUNT_ID=$2
  AWS_USERNAME=$3
  IAM_ROLE=$4
  MFA=$5

  if [ -z "$PROFILE_NAME" ]; then
    echo "Need AWS_PROFILE_CLI shell environment variable"
    exit 1;
  fi

  if [ -z "$ACCOUNT_ID" ]; then
    echo "Need ACCOUNT_ID shell environment variable"
    exit 1;
  fi

  if [ -z "$AWS_USERNAME" ]; then
    echo "Need AWS_USERNAME shell environment variable, which is your '_cli' user, e.g my_name_cli"
    exit 1;
  fi

  if [ -z "$IAM_ROLE" ] then
    echo "Need IAM_ROLE shell environment variable, which is the role name your are trying to assume, e.g developer, great-power"
    exit 1;
  fi


  AWS_PROFILE=${PROFILE_NAME} aws sts assume-role \
		--role-arn arn:aws:iam::"${ACCOUNT_ID}":role/"${IAM_ROLE}"\
		--role-session-name "${AWS_USERNAME}"\
		--serial-number arn:aws:iam::"${ACCOUNT_ID}":mfa/"${AWS_USERNAME}" \
		--token-code "${MFA}" > ./cred-"${PROFILE_NAME}" --duration-seconds 3600

  cat ./cred-"${PROFILE_NAME}"

  ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' ./cred-"${PROFILE_NAME}")
  SECRET_KEY=$(jq -r '.Credentials.SecretAccessKey' ./cred-"${PROFILE_NAME}")
  SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' ./cred-"${PROFILE_NAME}")

  aws configure set aws_access_key_id "${ACCESS_KEY_ID}" --profile "${PROFILE_NAME}"-temp
  aws configure set aws_secret_access_key "${SECRET_KEY}" --profile "${PROFILE_NAME}"-temp
  aws configure set aws_session_token "${SESSION_TOKEN}" --profile "${PROFILE_NAME}"-temp
  rm ./cred-"${PROFILE_NAME}"
}

assrole "${AWS_PROFILE_CLI}" "${ACCOUNT_ID}" "${AWS_USERNAME}" "${IAM_ROLE}" "$1"

```

#### Before and after of script and what it does to `~/.aws/credentials`

```ini
#BEFORE
[${PROFILE}]
aws_access_key_id = ${ACCESS_KEY_ID}
aws_secret_access_key = ${SECRET_ACCESS_KEY} #disclaimer: PLEASE DO NOT PASTE THIS VALUE TO ANYONE AS THIS IS YOUR PASSWORD
```

```ini
#AFTER
[${PROFILE}]
aws_access_key_id = ${ACCESS_KEY_ID}
aws_secret_access_key = ${SECRET_ACCESS_KEY} #disclaimer: PLEASE DO NOT PASTE THIS VALUE TO ANYONE AS THIS IS YOUR PASSWORD
[${PROFILE}-temp]
aws_access_key_id = xxxSOME_NEW_ACCESS_KEY_ID
aws_secret_access_key = xxxSOME_NEW_SECRET_ACCESS_KEY #disclaimer: PLEASE DO NOT PASTE THIS VALUE TO ANYONE AS THIS IS YOUR PASSWORD
aws_session_token = xxxSOME_VALUE
```

After this just run your command such as below to verify it works
> `AWS_PROFILE=xxx-temp aws s3 ls`

#### Advanced Method

In order to indicate to AWS to assume certain roles, we'll need to configure it so via the `role_arn` property.
We also implement a mandatory multi-factor authentication (2FA) for role assumptions that can be specified using the `mfa_serial` property

1. Edit `~/.aws/config` as follows, making the appropriate substitutions:
    ```ini
    [profile ${PROFILE}]
    mfa_serial = ${MFA_SERIAL}

    [profile ${AWS_USER}]
    source_profile = ${PROFILE}
    role_arn = ${ROLE_ARN}
    mfa_serial = ${MFA_SERIAL}
    ```

## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| aws  | > 2.7.0 |

## Inputs

| Name        | Description                                                                                               | Type     | Default                 | Required |
| ----------- | --------------------------------------------------------------------------------------------------------- | -------- | ----------------------- | :------: |
| aws\_region | aws region                                                                                                | `string` | n/a                     |   yes    |
| email       | official work email of the user                                                                           | `string` | `"someone@tech.gov.sg"` |    no    |
| name        | real name of the user                                                                                     | `string` | `"Monica Zheng"`        |    no    |
| pgp\_key    | pgp key to use to encrypt the access keys - use 'gpg --export %KEY\_ID% \| base64 -w 0' to get this value | `string` | n/a                     |   yes    |
| purpose     | a reason why this user should exist                                                                       | `string` | n/a                     |   yes    |
| username    | username for the user                                                                                     | `string` | `"gcc-default-user"`    |    no    |

## Outputs

| Name            | Description                                                                                             |
| --------------- | ------------------------------------------------------------------------------------------------------- |
| access\_key     | base64-encoded, encrypted access key of the user, use `base64 -d` to decrypt and `gpg -d encrypted.txt` |
| access\_key\_id | id of the access key                                                                                    |
| arn             | arn of the created iam user                                                                             |
| id              | id of the created iam user                                                                              |
| name            | username of the created iam user                                                                        |


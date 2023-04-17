# iam-users-gcc

Creates iam user with GCC permission boundary attached automatically

## Usage

```hcl
module 'iam-user-gcc' {
  name = "My Name"

  # official work email
  mail = "someone@tech.gov.sg"

  # create with `gpg --full-generate-key`, list with `gpg --list-secret-keys --keyid-format LONG` and get with `gpg --export %KEY_ID% | base64 -w 0`
  pgp_key = "mQINBF6qL/IdKGMQawxsCwUvm3Y4yjhC+WzAP7U7o48IMv0Zi0ichuvtTMJwsTLc6ym4fuBrYquzlu92PvDHb2EZKJNA9kW8t4mNQsVFtU6HQfpnnABSVed+eFBEQjBl89Jj9TlYBRBVqH0QYtPyUmrJcWxfbD7N3yQUPtJ8TLFSda+E/vG146a08eZsoKxMzb3dDCLf7nJ+epwmvIdspiI+/+fNNn7jqJC9RksL8OXrV9w+qN3u7Budxni/ZIecaenBFAs9IRn+4rfplvVlPyXLlb6w=="

  # add a reason for why this account needs to exist
  purpose = "devops usage"

  # Username in IAM users
  username = "my_name_cli"

}
```

## Prerequisites

This module assumes you, and the users that you are helping to create access tokens for have knowledge of aws cli,
otherwise please read [aws cli docs](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html) prior to
this so as to familiarise yourself with the various commands

For simplifying the shell script we use `jq`, therefore please
install [jq](https://github.com/stedolan/jq/wiki/Installation)

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
    7. Verify the **USER-ID** reflected back to you is correct (
       eg. `"someone (no comments)  <someone@tech.gov.sg>"`)
    8. Use **O** to indicate okay
    9. Enter in a key password and enter it in again to verify it
    10. Generate the random bytes the `gpg` program needs by surfing the web (if needed)
    11. You should see a key signature with `pub`, `uid`, and `sub` in the first column
3. If you completed step 2, run step 1 again and find the key you wish to use. The ID of they is on the same line as the
   row of information starting with **`sec   rsaXXXX/%KEY_ID% YYYY-MM-DD [SC] ....`**. Extract the `%KEY_ID%`.
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

1. The secret access key you will receive is base64-encoded and encrypted with your public key. To decrypt it,
   run `echo ${ENCRYPTED_SECRET_ACCESS_KEY} | base64 -d > ./aws_secret_access_key.enc`
2. Decrypt the file by running `gpg --decrypt ./aws_secret_access_key.enc > ./aws_secret_access_key`
3. Install [aws-vault](https://github.com/99designs/aws-vault) and run `aws-vault add my-project-my-username`. You'll be
   prompted to for your AWS Access Key ID and also your AWS Secret Access Key.

### Setup ~/.aws/config

> see https://github.com/99designs/aws-vault#roles-and-mfa

1. Create a file called ~/.aws/config with the following information

If you are using, aws-vault 6.6.x

```yaml
[ profile my-project-my-username ]
  credential_process=env AWS_SDK_LOAD_CONFIG=0 aws-vault exec my-project-my-username --no-session --duration=1h --json
```

If you are using, aws-vault 7.x.x and using terraform EKS module, you will need the following to allow assuming of eks admin role

```yaml
[ profile my-project-my-username ]
  credential_process=env aws-vault exec my-project-my-username --no-session --duration=1h --json
```

If you are using, aws-vault 7.x.x

```yaml
[ profile my-project-my-username ]
  aws-vault exec my-project-my-username --no-session --duration=1h --json
```

### Creating your virtual MFA

Before we assume a role, you'll need to create a virtual MFA via the [AWS CLI tool](https://aws.amazon.com/cli/) on your
local machine. This is because we have enabled MFA for all user access tokens on the group level, if your policy does
not require MFA, you may skip this step.

1. Install the [AWS CLI tool](https://aws.amazon.com/cli/).
2. Set the AWS cli to use the profile you defined above: `export AWS_PROFILE=${PROFILE}`
3. Run the following your terminal to create the virtual MFA:
    ```sh
    aws iam create-virtual-mfa-device --virtual-mfa-device-name ${AWS_USER} --outfile ~/mfa_${AWS_USER}.png --bootstrap-method QRCodePNG;
    ```
   A JSON response will be shown - note down the `MFA_SERIAL` returned. You will need this later.
4. Open the file at `~/mfa_${AWS_USER}.png` and scan it with your authenticator application, note two consecutive codes
   it generates.
5. Run the following in your terminal to enable the virtual MFA (replace `000000` and `111111` with the two generated
   codes):
    ```sh
    aws iam enable-mfa-device --user-name ${AWS_USER} --serial-number ${MFA_SERIAL} --authentication-code1 000000 --authentication-code2 111111
    ```
6. Your MFA set up is done!

   Add the MFA into your ~/.aws/config:
   If you are using, aws-vault 6.6.x
   ```yaml
   [profile my-project-my-username]
   mfa_serial=arn:aws:iam::123456789012:mfa/my-username # Add this line
   credential_process=env AWS_SDK_LOAD_CONFIG=0 aws-vault exec my-project-my-username --no-session --duration=1h --json
   ```
   If you are using, aws-vault 7.x.x and using terraform EKS module, you will need the following to allow assuming of eks admin role
   ```yaml
   [profile my-project-my-username]
   mfa_serial=arn:aws:iam::123456789012:mfa/my-username # Add this line
   credential_process=env aws-vault exec my-project-my-username --no-session --duration=1h --json
   ```

   If you are using, aws-vault 7.x.x
   ```yaml
   [profile my-project-my-username]
   mfa_serial=arn:aws:iam::123456789012:mfa/my-username # Add this line
   aws-vault exec my-project-my-username --no-session --duration=1h --json
   ```

*Note* `MFA_SERIAL` is arn:aws:iam::${ACCOUNT_ID}:mfa/${AWS_USER}

### Configuring AWS cli to assume roles

To access roles you are granted, you'll need to assume an IAM Role. IAM Roles which you can assume are based on the IAM
Groups you are in, and the IAM Roles affect your permissions on the various AWS resources.

1. Update your ~/.aws/config with the following information

If you are using, aws-vault 6.6.x

```yaml
[ profile my-project-my-username ]
  mfa_serial=arn:aws:iam::123456789012:mfa/my-username
  credential_process=env AWS_SDK_LOAD_CONFIG=0 aws-vault exec my-project-my-username --no-session --duration=1h --json

  [ profile my-project-my-role ]
  mfa_serial=arn:aws:iam::123456789012:mfa/my-username
  role_arn=arn:aws:iam::{ACCOUNTID}:role/role-to-assume
  source_profile=my-project-my-username
```

If you are using, aws-vault 7.x.x and using terraform EKS module, you will need the following to allow assuming of eks admin role

```yaml
[ profile my-project-my-username ]
  mfa_serial=arn:aws:iam::123456789012:mfa/my-username
  credential_process=env aws-vault exec my-project-my-username --no-session --duration=1h --json

  [ profile eks-admin-role ]
  mfa_serial=arn:aws:iam::123456789012:mfa/my-username
  role_arn=arn:aws:iam::{ACCOUNTID}:role/role-to-assume
  source_profile=my-project-my-username
```

If you are using, aws-vault 7.x.x

```yaml
[ profile my-project-my-username ]
  mfa_serial=arn:aws:iam::123456789012:mfa/my-username
  aws-vault exec my-project-my-username --no-session --duration=1h --json

  [ profile my-project-my-role ]
  mfa_serial=arn:aws:iam::123456789012:mfa/my-username
  role_arn=arn:aws:iam::{ACCOUNTID}:role/role-to-assume
  source_profile=my-project-my-username
```

2. run `aws-vault exec my-project-my-role` and type in your 2fa when requested
3. Check that you have assumed the role correctly by testing `aws` commands that is allowed with your role.

### Troubleshooting

#### `SignatureDoesNotMatch` errors

This error occurs when the secret key provided to `aws-vault` was corrupted in the `aws-vault add` process.
This might be due to the shell interferring with the secret key value (which might have escape characters).

```
An error occurred (SignatureDoesNotMatch) when calling the CreateVirtualMFADevice operation: The request signature we calculated does not match the signature you provided.
```

1. Remove the existing, invalid credentials - `aws-vault remove my-project-my-username`
2. Follow the guide above to add the credentials via environment variables instead.

#### `ExpiredToken` errors

If during the MFA creation process, you get the following error:

```
An error occurred (ExpiredToken) when calling the CreateVirtualMFADevice operation: The security token included in the request is expired
```

There might be an issue with your `aws-vault` setup - try using a **new, unpolluted terminal session**, and define your
AWS access key and secret as environment vars:

```sh
export AWS_ACCESS_KEY_ID=XXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXX
```

And try the command again.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| aws  | > 2.7.0 |

## Inputs

| Name        | Description                                                               | Type                           | Default                 | Required |
|-------------|---------------------------------------------------------------------------|--------------------------------|-------------------------|:--------:|
| aws\_region | aws region                                                                | `string`                       | n/a                     |   yes    |
| email       | official work email of the user                                           | `string`                       | `"someone@tech.gov.sg"` |    no    |
| name        | real name of the user                                                     | `string`                       | `"Monica Zheng"`        |    no    |
| pgp\_key    | pgp key to use to encrypt the access keys - use 'gpg --export %KEY\_ID% \ | base64 -w 0' to get this value | `string`                |   n/a    |   yes    |
| purpose     | a reason why this user should exist                                       | `string`                       | n/a                     |   yes    |
| username    | username for the user                                                     | `string`                       | `"gcc-default-user"`    |    no    |

## Outputs

| Name            | Description                                                                                             |
|-----------------|---------------------------------------------------------------------------------------------------------|
| access\_key     | base64-encoded, encrypted access key of the user, use `base64 -d` to decrypt and `gpg -d encrypted.txt` |
| access\_key\_id | id of the access key                                                                                    |
| arn             | arn of the created iam user                                                                             |
| id              | id of the created iam user                                                                              |
| name            | username of the created iam user                                                                        |


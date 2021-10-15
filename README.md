# aws-serverless-backend

Creates an api gateway with each route connected to a separate lambda.

## Features

- Creates an api gateway with all the requisite resources based on the paths provided
- Every method is mapped to its own Lambda
- An IAM user named like `api_name-lambda` is created that is given deployment access to the lambdas
- Currently only supports resources one path deep

## Usage

```hcl
provider "aws" {
    region = "us-east-1"
}

module "aws_serverless_backend" {
    source    = "dvargas92495/serverless-backend/aws"

    api_name = "example"
    paths = [
        "resource/get",
        "another_resource/post"
    ]
    domain = "example.com"
}
```

## Inputs

- `api_name` is name given to the api.
- `paths` are the list of paths the API supports. By default, it will read the `functions` directory.
- `tags` are a map of tags to add to all resources. By default, it includes 1 Application tag mapping to the `api_name`.
- `domain` is the domain that the api will be mapped to. By default, it will use tha API name, remapping `-` to `.`.

## Output

- `rest_api_id` the id of the created rest api
- `access_key` the AWS_ACCESS_KEY_ID of the created user
- `secret_key` the AWS_SECRET_ACCESS_KEY of the created user
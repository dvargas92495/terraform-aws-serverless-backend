provider "aws" {
    region = "us-east-1"
}

module "aws-serverless-backend" {
    source = "../.."

    api_name = "example"
    paths = [
        "resource/get"
    ]
}
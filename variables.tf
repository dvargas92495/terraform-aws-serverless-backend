variable "api_name" {
    type = string
    description = "The name to give the Rest API"
}

variable "paths" {
  type        = list
  description = "The list of paths the API supports. By default, it will read the `functions` directory."
  default     = []
}

variable "tags" {
    type        = map
    description = "A map of tags to add to all resources. By default, it includes 1 Application tag mapping to the api_name"
    default     = {
        Application = var.api_name
    }
}

variable "domain" {
    type        = string
    description = "The domain that the api will be mapped to. By default, it will use tha API name, remapping `-` to `.`"
    default = ""
}

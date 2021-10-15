variable "paths" {
  type        = list
  description = "The list of paths the API supports. By default, it will read the `functions` directory"
  default     = []
}

variable "api_name" {
    type = string
    description = "The name to give the Rest API"
}

variable "tags" {
    type        = map
    description = "A map of tags to add to all resources"
    default     = {}
}

variable "domain" {
    type        = string
    description = "The domain that the api will be mapped to."
}

variable "cors" {
    type        = list
    description = "The list of resources that will restrict cors to the input domain. This variable is temporary until all endpoints use domain to restrict CORS."
    default = []
}

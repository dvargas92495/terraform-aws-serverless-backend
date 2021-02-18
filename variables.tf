variable "paths" {
  type        = list
  description = "The list of paths the API supports."
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

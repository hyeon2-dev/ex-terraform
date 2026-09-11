# variables.tf

variable "region" {
    description = "AWS region"
    type        = string
    default     = "us-west-2"
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type        = string
    default     = "10.0.0.0/16"
}

# count 사용할때 사용
# variable "subnet_cidr" {
#     description = "CIDR block for the subnet"
#     type        = list(list(string))
#     default     = [
#         ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"],
#         ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24", "10.0.14.0/24"]
#     ]
# }

# for_each 사용할때 사용
variable "subnet_cidr" {
    description = "CIDR block for the subnet"
    type        = list(map(string))
    default     = [
        {
            us-west-2a = "10.0.1.0/24",
            us-west-2b = "10.0.2.0/24",
            us-west-2c = "10.0.3.0/24",
            us-west-2d = "10.0.4.0/24"
        },
        {
            us-west-2a = "10.0.11.0/24",
            us-west-2b = "10.0.12.0/24",
            us-west-2c = "10.0.13.0/24",
            us-west-2d = "10.0.14.0/24"
        }
    ]
}



variable "default_name" {
    description = "Default_name for resources"
    type        = string
    default     = ""
}


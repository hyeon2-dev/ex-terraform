variable "tag_header" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "One private subnet per Availability Zone"
  type        = map(string)
}

variable "web_sg_id" {
  description = "Security group attached to EC2 mounting EFS"
  type        = string
}
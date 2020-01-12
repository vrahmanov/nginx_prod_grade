output "sg_lb" {
  description = "The ARN of the ECS cluster."
  value       = aws_security_group.lb.id
}

output "sg_ecs" {
  description = "The name of the ECS sg."
  value       = aws_security_group.ecs_tasks.name # .main.name
}

output "alb" {
  description = "The name of the ECS instance role."
  value       = aws_alb.main.arn  # aws_iam_role.ecs_instance_role.name
}
output "alb_access" {
  description = "The name of the ECS instance role."
  value       = aws_alb.main.dns_name  # aws_iam_role.ecs_instance_role.name
}

output "tg" {
  value = aws_alb_target_group.app.arn
}
//output "alb_tg" {
//  description = "The name of the ECS instance role."
//  value       = aws_alb.main. #.name  # aws_iam_role.ecs_instance_role.name
//}

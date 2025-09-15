output "ingest_workflow_arn" {
  description = "Ingest workflow state machine ARN"
  value       = aws_sfn_state_machine.ingest_workflow.arn
}

output "process_workflow_arn" {
  description = "Process workflow state machine ARN"
  value       = aws_sfn_state_machine.process_workflow.arn
}

output "publish_workflow_arn" {
  description = "Publish workflow state machine ARN"
  value       = aws_sfn_state_machine.publish_workflow.arn
}
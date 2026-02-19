output "api_endpoint" {
  description = "Base URL for the Visitor Counter API"
  value       = "${aws_apigatewayv2_stage.prod.invoke_url}/visitor-count"
}
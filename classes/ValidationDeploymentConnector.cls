/**
 * Custom connector to create a promotion and execute promotion and deployment actions
 * for validation deployments in Source Format Pipelines
 */
global with sharing class ValidationDeploymentConnector extends copado.AutomationConnector {
    
    /**
     * This method prepares the necessary data and returns connector instances
     */
    global override List<copado.AutomationConnector> getConnectors(copado.AutomationConnectorContext context) {
        // Return this instance to be executed
        return new List<copado.AutomationConnector>{ this };
    }
    
    /**
     * This method executes the automation (creates promotion and executes actions for validation)
     */
    global override String executeAutomation() {
        try {
            // Step 1: Create a Promotion Record for validation
            copado__Promotion__c promotion = createValidationPromotion();
            System.debug('Created Validation Promotion: ' + promotion.Id);
            
            // Step 2: Execute Promote Action
            copado.PromoteAction.Request promoteRequest = new copado.PromoteAction.Request();
            promoteRequest.promotionId = promotion.Id;
            promoteRequest.executePromotion = true;
            
            List<copado.PromoteAction.Response> promoteResponses = copado.PromoteAction.promote(new List<copado.PromoteAction.Request>{ promoteRequest });
            String promoteJobId = !promoteResponses.isEmpty() ? promoteResponses[0].jobExecution.Id : null;
            
            System.debug('Promote Action executed with job execution ID: ' + promoteJobId);
            
            // Step 3: Execute Deployment Action with validation only
            copado.Actions.PromotionDeploymentRequest deployRequest = new copado.Actions.PromotionDeploymentRequest();
            deployRequest.promotionId = promotion.Id;
            deployRequest.deploymentDryRun = true; // This makes it a validation only
            
            copado.Actions.PromotionDeploymentResult deployResult = copado.Actions.PromotionDeploymentService.execute(deployRequest);
            String deployJobId = deployResult.jobExecution.Id;
            
            System.debug('Deployment Action executed with job execution ID: ' + deployJobId);
            
            return 'Successfully initiated validation promotion and deployment actions. ' +
                   'Promotion: ' + promotion.Id + 
                   ', Promote Job: ' + (promoteJobId != null ? promoteJobId : 'N/A') +
                   ', Deploy Job: ' + (deployJobId != null ? deployJobId : 'N/A');
                   
        } catch (Exception e) {
            System.debug('Error in ValidationDeploymentConnector.executeAutomation: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return 'Error: ' + e.getMessage();
        }
    }
    
    /**
     * Creates a new promotion record for validation
     */
    private copado__Promotion__c createValidationPromotion() {
        // Create a new promotion for validation - replace these values with your actual values
        copado__Promotion__c promotion = new copado__Promotion__c(
            copado__Project__c = 'a0x1h000003Lc7QAAS', // Replace with your actual Project Id
            copado__Source_Environment__c = 'a0v1h000002vkJJAAY', // Replace with your Source Environment Id
            copado__Destination_Environment__c = 'a0v1h000002vkJOAAY', // Replace with your Destination Environment Id
            copado__Status__c = 'Draft'
        );
        
        insert promotion;
        
        // Set status to In Progress to make it ready for actions
        promotion.copado__Status__c = 'In Progress';
        update promotion;
        
        return promotion;
    }
    
    /**
     * This method returns the name of the automated action
     */
    global override String getAutomatedActionName() {
        return 'Validation Deployment';
    }
}
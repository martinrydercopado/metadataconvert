@IsTest
public with sharing class AutomationResultTest {
    @IsTest
    public static void execute() {
        //Setup
        String executionId = String.valueOf(Integer.valueOf(Math.random() * 10000));
        String suiteId = 'b';
        String projectId = 'a';
        copado__JobStep__c step;
        copado__Result__c res;

        Test.setMock(HttpCalloutMock.class, new ApiMock(projectId, suiteId, executionId));
        // Exercise
        Test.startTest();
        AutomationDetails details = new AutomationDetails(projectId, suiteId, executionId);

        copado__JobExecution__c execution = new copado__JobExecution__c();
        insert execution;
        step = new copado__JobStep__c(
            copado__JobExecution__c=execution.id,
            copado__Type__c='Flow',
            copado__ResultDataJson__c=JSON.serialize(details)
        );
        insert step;
        res = new copado__Result__c(
            copado__JobStep__c=step.Id,
            copado__Job_Type__c='Run_CRT'
        );
        insert res;
        Test.stopTest();

        Boolean isRunning = AutomationResult.execute(step);
        copado__Result__c result = [SELECT Id, copado__Job_Id__c, copado__Status__c FROM copado__Result__c WHERE Id = :res.Id];
        //Verify
        Assert.areEqual(isRunning, false);
        Assert.areEqual(executionId, result.copado__Job_Id__c);
        Assert.areEqual('Success', result.copado__Status__c);
    }

    @IsTest
    public static void executeFailed() {
        //Setup
        String executionId = String.valueOf(Integer.valueOf(Math.random() * 10000));
        String suiteId = 'b';
        String projectId = 'a';
        String status = 'failure';
        copado__JobStep__c step;
        copado__Result__c res;

        ApiMock mock = new ApiMock(projectId, suiteId, executionId);

        Test.setMock(HttpCalloutMock.class, mock.status(status));
        // Exercise
        Test.startTest();
        AutomationDetails details = new AutomationDetails(projectId, suiteId, executionId);

        copado__JobExecution__c execution = new copado__JobExecution__c();
        insert execution;
        step = new copado__JobStep__c(
            copado__JobExecution__c=execution.id,
            copado__Type__c='Flow',
            copado__ResultDataJson__c=JSON.serialize(details)
        );
        insert step;
        res = new copado__Result__c(
            copado__JobStep__c=step.Id,
            copado__Job_Type__c='Run_CRT'
        );
        insert res;
        Test.stopTest();

        Boolean isRunning = AutomationResult.execute(step);
        copado__Result__c result = [SELECT Id, copado__Job_Id__c, copado__Status__c FROM copado__Result__c WHERE Id = :res.Id];
        //Verify
        Assert.areEqual(isRunning, false);
        Assert.areEqual(executionId, result.copado__Job_Id__c);
        Assert.areEqual('Failed', result.copado__Status__c);
    }
}
@IsTest 
public with sharing class AutomationDetailsTest {
    @IsTest
    public static void constructorTest() {
        String suiteId = 'a';
        String projectId = 'b';
        String executionId = 'c';
        String sessionId = 'sessionId';
        String endpoint = 'https://endpoint.com/url/url';
        AutomationDetails details = new AutomationDetails(projectId, suiteId);
        details = details.executionId(executionId).loginUrl(endpoint, sessionId);

        Assert.areEqual(details.suiteId, suiteId);
        Assert.areEqual(details.projectId, projectId);
        Assert.areEqual(details.executionId, executionId);
    }

    @IsTest
    public static void constructorTestFull() {
        String suiteId = 'a';
        String projectId = 'b';
        String executionId = 'c';
        String sessionId = 'sessionId';
        String endpoint = 'https://endpoint.com/url/url';
        AutomationDetails details = new AutomationDetails(projectId, suiteId, executionId);
        details = details.loginUrl(endpoint, sessionId);

        Assert.areEqual(details.suiteId, suiteId);
        Assert.areEqual(details.projectId, projectId);
        Assert.areEqual(details.executionId, executionId);
    }
}
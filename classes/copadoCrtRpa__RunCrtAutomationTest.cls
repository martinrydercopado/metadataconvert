@IsTest
public with sharing class RunCrtAutomationTest {
    @TestSetup
    private static void setUp() {
        createUser();
    }

    @IsTest
    public static void execute() {
        System.runAs(getRunAsUser()) {
            //Setup
            String projectId = 'a';
            String suiteId = 'b';
            String executionId = String.valueOf(Integer.valueOf(Math.random() * 10000));
            String loginUrl = 'https://url.com/url/url';
            copado__JobStep__c step;
            copado__Result__c res;

            ApiMock mock = new ApiMock(projectId, suiteId);
            Test.setMock(HttpCalloutMock.class, mock.executionId(executionId));
            // Exercise
            Test.startTest();

            copado__Environment__c env = new copado__Environment__c(Name = 'Mock Dev 1', copado__Type__c = 'Sandbox');
            insert env;

            copado__Org__c org = new copado__Org__c(
                Name = 'Mock Dev',
                copado__Org_Type__c = 'Sandbox',
                copado__Validated_Date__c = Datetime.now(),
                copado__Environment__c = env.Id,
                copado__SFDC_Org_ID__c = 'SFDC_Dev1OrgId',
                OwnerId = getRunAsUser().Id
            );
            insert org;
            copado__JobExecution__c execution = new copado__JobExecution__c(
                copado__Destination__c=env.Id
            );
            insert execution;
            step = new copado__JobStep__c(
                copado__JobExecution__c=execution.id,
                copado__Type__c='Flow'
            );
            insert step;
            res = new copado__Result__c(
                copado__JobStep__c=step.id,
                copado__Job_Type__c='Salesforce Flow'
            );
            insert res;
            Test.stopTest();

            List<RunCrtAutomation.Parameters> params = new List<RunCrtAutomation.Parameters>();
            RunCrtAutomation.Parameters param = new RunCrtAutomation.Parameters();
            param.projectId = projectId;
            param.suiteId = suiteId;
            param.resultId = res.Id;
            params.add(param);
            RunCrtAutomation.execute(params);
            copado__JobStep__c result = [SELECT Id, copado__ResultDataJson__c FROM copado__JobStep__c WHERE Id = :step.Id];
            //Verify
            Assert.isNotNull(result.copado__ResultDataJson__c);
        }
    }

    public static User createUser() {
        User runAsUser = new User(
            LastName = 'UserLastName',
            Username = 'username@myemail.com',
            Email = 'username@myemail.com',
            Alias = 'MyAlias',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = UserInfo.getProfileId(),
            LanguageLocaleKey = 'en_US'
        );
        insert runAsUser;
        return runAsUser;
    }

    public static User getRunAsUser() {
        User user = [SELECT Id FROM User WHERE Username = 'username@myemail.com' LIMIT 1];

        return user;
    }
}
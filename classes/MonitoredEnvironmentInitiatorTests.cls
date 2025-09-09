@isTest
public class MonitoredEnvironmentInitiatorTests {
    @TestSetup
    private static void createData() {
        MonitorTestHelper.setup();
    }
    @isTest
    public static void GetDefaultCredentialsForEnvironment()
    {
        Boolean exceptionThrown = false;
        List<string> ids = new List<string>();

        string missingCredentialId = 'MissingCredentialID';
        try {
            exceptionThrown = false;

            ids.clear();
            ids.add(missingCredentialId);

            MonitoredEnvironmentInitiator.GetDefaultCredentialUsernames(ids);

        } catch (MonitoringException e) {
            exceptionThrown = true;
            System.assertEquals('Could not find Default Credential records with IDs: ' + missingCredentialId, e.getMessage());
        }

        System.assertEquals(true, exceptionThrown);

        //Valid Use case of one 
        copado__Environment__c environment;
        try {
            exceptionThrown = false;

            environment = new copado__Environment__c(
                Name = 'Test environment 1',
                copado__Type__c = 'Sandbox',
                copado__Org_ID__c = '123456789012345678'
            );

            insert environment;

            copado__Org__c org = new copado__Org__c(
                copado__Environment__c = environment.ID,
                copado__Default_Credential__c = true,
                copado__Org_Type__c = 'Sandbox',
                copado__Username__c = ''
            );

            insert org;

            ids.clear();
            ids.add(environment.Id);

            MonitoredEnvironmentInitiator.GetDefaultCredentialUsernames(ids);
        } catch (MonitoringException e) {
            exceptionThrown = true;
        }

        System.assertEquals(false, exceptionThrown);
    }

    @isTest
    public static void FlowEntryPoint()
    {
        System.runAs(MonitorTestHelper.getRunAsUser()){
            copado__Git_Repository__c repo = new copado__Git_Repository__c(
                copado__Git_Provider__c = 'Github',
                copado__Branch_Base_URL__c = 'main',
                copado__Source_Format__c = 'Metadata'
            );

            insert repo;

            copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c(
                copado__Git_Repository__c = repo.id,
                COPADO__ENABLE_COPADO_DX__C = false,
                COPADO__MAIN_BRANCH__C = 'main'
            );

            insert pipeline;

            copado__Environment__c environment = new copado__Environment__c(
                    Name = 'Test environment 1',
                    copado__Type__c = 'Sandbox',
                    copado__Org_ID__c = '123456789012345678'
                );
            insert environment;

            copado__Deployment_Flow_Step__c deploymentStep = new copado__Deployment_Flow_Step__c(
                copado__Source_Environment__c = environment.ID,
                copado__Deployment_Flow__c = pipeline.ID
            );
            insert deploymentStep;

            Monitored_Environments__c monitoredEnvironment = new Monitored_Environments__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID
                );
            insert monitoredEnvironment;

            copado__Org__c org = new copado__Org__c(
                    copado__Environment__c = environment.ID,
                    copado__Default_Credential__c = true,
                    copado__Org_Type__c = 'Sandbox',
                    copado__Username__c = 'Default Org Credential Username'
                );
            insert org;

            copado__Deployment__c deployment = new copado__Deployment__c(
                copado__From_Org__c = org.ID
            );
            insert deployment;

            copado__Destination_Org__c destinationOrg = new copado__Destination_Org__c(
                copado__Deployment__c = deployment.ID,
                copado__To_Org__c = org.ID
            );
            insert destinationOrg;

            copado__Step__c step = new Copado__Step__c(
                    copado__Deployment__c = deployment.ID
                );
            insert step;

            copado__Deployment_Job__c deploymentJob = new copado__Deployment_Job__c(
                copado__status__c = 'Success',
                copado__Step__c = step.ID,
                copado__Destination_Org__c = destinationOrg.ID
            );
            insert deploymentJob;

            copado__Result__c result = new copado__Result__c(
                    copado__job_id__c = null,
                    copado__Job_Type__c = 'Unit Test'
            );
            insert result;

            MonitoredEnvironmentInitiator.testingFunctionResults = new List<string> { result.ID };

            Test.startTest();

            MonitoredEnvironmentInitiator.FlowEntryPoint(new List<string> { monitoredEnvironment.ID });

            Test.stopTest();

            result = [SELECT ID,copado__job_id__c
                    FROM copado__Result__c 
                    WHERE ID = :result.ID 
                    LIMIT 1];

            System.assert(result.copado__job_id__c != null,'Verify that the Log ID is saved to the Result object');
        }
    }
}
@isTest
public class MonitoredEnvironmentCallbackTests {
    @TestSetup
    private static void createData() {
        MonitorTestHelper.setup();
    }
    @isTest
    public static void LogSuccess()
    {
        System.runAs(MonitorTestHelper.getRunAsUser()){
            Boolean exceptionThrown = false;

            //Verify valid monitored environment
            try {
                exceptionThrown = false;

                copado__Environment__c environment = new copado__Environment__c(
                    Name = 'Test environment 1',
                    copado__Type__c = 'Sandbox',
                    copado__Org_ID__c = '123456789012345678'
                );

                insert environment;

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

                Monitored_Environments__c monitoredEnvironment = new Monitored_Environments__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID
                );

                insert monitoredEnvironment;

                copado__Result__c result = new copado__Result__c(
                    copado__Job_Type__c = 'setup_audit_trail'
                );

                insert result;

                Monitoring_Log__c successLog = new Monitoring_Log__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID,
                    Integration_User__c = 'IntegrationUserName',
                    Monitored_Environment__c = monitoredEnvironment.ID,
                    Function_Result__c = result.ID
                );
                insert successLog;

                //Validate our pre-test state
                System.assert(successLog.Status__c == null);
                System.assert(successLog.End_Date__c == null);

                System.assert(monitoredEnvironment.Last_Successful_Scan__c == null);
                System.assert(monitoredEnvironment.Last_Scan_Status__c == null);
                System.assert(monitoredEnvironment.Last_Monitoring_Log__c == null);

                Test.startTest();

                MonitoredEnvironmentCallback.LogSuccess(successLog,monitoredEnvironment);

                Test.stopTest();

                successLog = [SELECT Status__c, End_Date__c
                            FROM Monitoring_Log__c 
                            WHERE ID = :successLog.ID
                            LIMIT 1];

                System.assertEquals('Success', successLog.Status__c);
                System.assert(successLog.End_Date__c != null);

                monitoredEnvironment = [SELECT Last_Successful_Scan__c,Last_Scan_Status__c,Last_Monitoring_Log__c
                                        FROM   Monitored_Environments__c
                                        WHERE  ID = :monitoredEnvironment.ID
                                        LIMIT 1];

                System.assert(monitoredEnvironment.Last_Successful_Scan__c != null);
                System.assertEquals('Success',monitoredEnvironment.Last_Scan_Status__c);
                System.assertEquals(successLog.ID,monitoredEnvironment.Last_Monitoring_Log__c);
                
            } catch (MonitoringException e) {
                exceptionThrown = true;
            }

            System.assertEquals(false, exceptionThrown);
        }
    }

    @isTest
    public static void LogError()
    {
        System.runAs(MonitorTestHelper.getRunAsUser()){
            Boolean exceptionThrown = false;

            //Verify valid monitored environment
            try {
                exceptionThrown = false;

                copado__Environment__c environment = new copado__Environment__c(
                    Name = 'Test environment 1',
                    copado__Type__c = 'Sandbox',
                    copado__Org_ID__c = '123456789012345678'
                );

                insert environment;

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

                Monitored_Environments__c monitoredEnvironment = new Monitored_Environments__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID
                );

                insert monitoredEnvironment;

                copado__Result__c result = new copado__Result__c(
                    copado__Job_Type__c = 'setup_audit_trail'
                );

                insert result;

                Monitoring_Log__c log = new Monitoring_Log__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID,
                    Integration_User__c = 'IntegrationUserName',
                    Monitored_Environment__c = monitoredEnvironment.ID,
                    Function_Result__c = result.ID
                );
                insert log;

                //Validate our pre-test state
                System.assert(log.Status__c == null);
                System.assert(log.End_Date__c == null);

                System.assert(monitoredEnvironment.Last_Successful_Scan__c == null);
                System.assert(monitoredEnvironment.Last_Scan_Status__c == null);
                System.assert(monitoredEnvironment.Last_Monitoring_Log__c == null);

                string errorMessage = 'Error Message';
                string stackTrance = 'Stack Trace';

                Test.startTest();

                MonitoredEnvironmentCallback.LogError(log,monitoredEnvironment,errorMessage,stackTrance);

                Test.stopTest();

                log = [SELECT Status__c, End_Date__c, Error_Message__c
                            FROM Monitoring_Log__c 
                            WHERE ID = :log.ID
                            LIMIT 1];

                System.assertEquals('Failed', log.Status__c);
                System.assert(log.End_Date__c != null);
                System.assert(log.Error_Message__c != null);

                monitoredEnvironment = [SELECT Last_Successful_Scan__c,Last_Scan_Status__c,Last_Monitoring_Log__c
                                        FROM   Monitored_Environments__c
                                        WHERE  ID = :monitoredEnvironment.ID
                                        LIMIT 1];

                System.assertEquals('Failed',monitoredEnvironment.Last_Scan_Status__c);
                System.assertEquals(log.ID,monitoredEnvironment.Last_Monitoring_Log__c);
                
            } catch (MonitoringException e) {
                exceptionThrown = true;
            }

            System.assertEquals(false, exceptionThrown);
        }
    }
    
    @isTest
    public static void ProcessUserDetails()
    {
        System.runAs(MonitorTestHelper.getRunAsUser()){
            Boolean exceptionThrown = false;

            //Verify null file body throws exception
            try {
                exceptionThrown = false;
                MonitoredEnvironmentCallback.ProcessUserDetails('contentDocumentId not used though');
            } catch (MonitoringException e) {
                exceptionThrown = true;
                System.assertEquals('Could not get file body for user details', e.getMessage());
            }

            System.assertEquals(true, exceptionThrown);

            //Verify no user details found throws exception
            try {
                exceptionThrown = false;

                MonitoredEnvironmentCallback.Test_FileBody = '{ "totalSize": 0, "done": true, "records": [ ] }';

                MonitoredEnvironmentCallback.ProcessUserDetails('contentDocumentId not used though');
            } catch (MonitoringException e) {
                exceptionThrown = true;
                System.assertEquals('Could not find integration user\'s full name', e.getMessage());
            }

            System.assertEquals(true, exceptionThrown);

            //Verify valid user details found
            try {
                exceptionThrown = false;

                MonitoredEnvironmentCallback.Test_FileBody = '{ "totalSize": 0, "done": true, "records": [ { "attributes": { "type": "User", "url": "/services/data/v49.0/sobjects/User/0055e000000iDiIAAU" }, "Name": "Admin User" } ] }';

                MonitoredEnvironmentCallback.ProcessUserDetails('contentDocumentId not used though');
            } catch (MonitoringException e) {
            }

            System.assertEquals(false, exceptionThrown);
            System.assertEquals('Admin User',MonitoredEnvironmentCallback.IntegrationUserFullName);
        }
    }

    @isTest
    public static void ProcessMetadataChanges()
    {
        System.runAs(MonitorTestHelper.getRunAsUser()){
            SetupIDs setupIds = SetupFileProcessTestData();

            Boolean exceptionThrown = false;

            //Verify null file body throws exception
            try {
                exceptionThrown = false;
                MonitoredEnvironmentCallback.ProcessMetadataChanges(setupIds.environmentId,setupIds.monitoredEnvironmentId,'contentDocumentId not used though');
            } catch (MonitoringException e) {
                exceptionThrown = true;
                System.assertEquals('Could not get file body for metadata changes', e.getMessage());
            }

            System.assertEquals(true, exceptionThrown);


            //Make a dynamic username and add it to the JSON below
            string actingUsername = Datetime.now().getTime().format();
            string impersonationJson = '{ "totalSize": 1, "done": true, "records": [ { "attributes": { "type": "SetupAuditTrail", "url": "/services/data/v49.0/sobjects/SetupAuditTrail/0Ym2f00000Ly8vOCAR" }, "CreatedDate": "2021-05-17T23:27:26.000+0000", "CreatedBy": { "attributes": { "type": "User", "url": "/services/data/v49.0/sobjects/User/0055e000001K7GJAA0" }, "Name": "Standard User", "Username": "' + actingUsername + '" }, "Action": "changedApexClass", "Section": "Apex Class", "Display": "Changed TestClass2 Apex Class code", "DelegateUser": null } ] }';
            MonitoredEnvironmentCallback.Test_FileBody = impersonationJson;

            //Valid JSON will add one record
            try {
                exceptionThrown = false;
                MonitoredEnvironmentCallback.ProcessMetadataChanges(setupIds.environmentId,setupIds.monitoredEnvironmentId,'contentDocumentId not used though');
            } catch (MonitoringException e) {
                exceptionThrown = true;
            }

            List<Monitoring_Metadata_Change_Alert__c> alerts = [SELECT ID
                                                                FROM   Monitoring_Metadata_Change_Alert__c
                                                                WHERE  Username__c = :actingUsername];

            System.assertEquals(1, alerts.size());
            System.assertEquals(false, exceptionThrown);
        }
    }
    
    @isTest
    public static void ProcessImpersonations()
    {
        System.runAs(MonitorTestHelper.getRunAsUser()){
            SetupIDs setupIds = SetupFileProcessTestData();

            Boolean exceptionThrown = false;

            //Verify null file body throws exception
            try {
                exceptionThrown = false;
                MonitoredEnvironmentCallback.ProcessImpersonations(setupIds.environmentId,setupIds.monitoredEnvironmentId,'contentDocumentId not used though');
            } catch (MonitoringException e) {
                exceptionThrown = true;
                System.assertEquals('Could not get file body for impersonations', e.getMessage());
            }

            System.assertEquals(true, exceptionThrown);

            string integrationUserFullName = 'Admin User';
            string actingUserName = Datetime.now().getTime().format();

            string impersonationJson = '{"totalSize":3,"done":true,"records":[{"attributes":{"type":"SetupAuditTrail","url":"/services/data/v49.0/sobjects/SetupAuditTrail/0Ym2f00000LwACXCA3"},"Id":"0Ym2f00000LwACXCA3","CreatedDate":"2021-05-12T16:50:52.000+0000","CreatedBy":{"attributes":{"type":"User","url":"/services/data/v49.0/sobjects/User/0055e000000iDiIAAU"},"Name":"Admin User","Username":"AdminUser"},"Display":"Logged in using Login-As access for Standard User"},{"attributes":{"type":"SetupAuditTrail","url":"/services/data/v49.0/sobjects/SetupAuditTrail/0Ym2f00000Ly8fMCAR"},"Id":"0Ym2f00000Ly8fMCAR","CreatedDate":"2021-05-17T22:33:24.000+0000","CreatedBy":{"attributes":{"type":"User","url":"/services/data/v49.0/sobjects/User/0055e000000iDiIAAU"},"Name":"Admin User","Username":"AdminUserName"},"Display":"Logged in using Login-As access for Standard User"},{"attributes":{"type":"SetupAuditTrail","url":"/services/data/v49.0/sobjects/SetupAuditTrail/0Ym2f00000Ly8viCAB"},"Id":"0Ym2f00000Ly8viCAB","CreatedDate":"2021-05-17T23:30:42.000+0000","CreatedBy":{"attributes":{"type":"User","url":"/services/data/v49.0/sobjects/User/0055e000001K7GJAA0"},"Name":"Standard User","Username":"' + actingUserName + '"},"Display":"Logged in using Login-As access for ' + integrationUserFullName + '"}]}';
            MonitoredEnvironmentCallback.Test_FileBody = impersonationJson;
            MonitoredEnvironmentCallback.IntegrationUserFullName = integrationUserFullName;

            List<Monitoring_Impersonation_Alert__c> alerts = [SELECT ID 
                                                            FROM   Monitoring_Impersonation_Alert__c
                                                            WHERE  Username__c = :actingUserName];

            System.assertEquals(0, alerts.size());

            //Verify valid path returns one record and filters the other two out as non-integration user imperesonations
            try {
                exceptionThrown = false;
                MonitoredEnvironmentCallback.ProcessImpersonations(setupIds.environmentId,setupIds.monitoredEnvironmentId,'contentDocumentId not used though');
            } catch (MonitoringException e) {
                exceptionThrown = true;
            }

            alerts = [SELECT ID 
                    FROM   Monitoring_Impersonation_Alert__c
                    WHERE  Username__c = :actingUserName];

            System.assertEquals(1, alerts.size());
            System.assertEquals(false, exceptionThrown);
        }
    }
    
    public class SetupIDs
    {
        public string environmentId;
        public string monitoredEnvironmentId;

        public SetupIDs(string envId, string monEnvId) {
            environmentId = envId;
            monitoredEnvironmentId = monEnvId;
        }
    }

    @isTest
    private static SetupIDs SetupFileProcessTestData()
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


            copado__Deployment_Flow_Step__c step = new copado__Deployment_Flow_Step__c(
                copado__Source_Environment__c = environment.ID,
                copado__Deployment_Flow__c = pipeline.ID
            );

            insert step;

            Monitored_Environments__c monitoredEnvironment = new Monitored_Environments__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID
                );

            insert monitoredEnvironment;
            return new SetupIDs(environment.ID,monitoredEnvironment.Id);
        }
        return null;
    }

    @isTest
    public static void GetPipeline()
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


            copado__Deployment_Flow_Step__c step = new copado__Deployment_Flow_Step__c(
                copado__Source_Environment__c = environment.ID,
                copado__Deployment_Flow__c = pipeline.ID
            );

            insert step;

            Monitored_Environments__c monitoredEnvironment = new Monitored_Environments__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID
                );

            insert monitoredEnvironment;

            string actualPipelineID = MonitoredEnvironmentCallback.GetPipeline(environment.ID);

            System.assertEquals(pipeline.ID,actualPipelineID);
        }
    }

    @isTest
    public static void GetMonitoredEnvironment()
    {
        System.runAs(MonitorTestHelper.getRunAsUser()){
            Boolean exceptionThrown = false;

            //Verify null environment ID exception
            try {
                exceptionThrown = false;
                MonitoredEnvironmentCallback.GetMonitoredEnvironment(null);
            } catch (MonitoringException e) {
                exceptionThrown = true;
                System.assertEquals('Function was not able to link Monitored Environment ID correctly.', e.getMessage());
            }

            System.assertEquals(true, exceptionThrown);

            //Verify no environment found link
            try {
                exceptionThrown = false;
                MonitoredEnvironmentCallback.GetMonitoredEnvironment('');
            } catch (MonitoringException e) {
                exceptionThrown = true;
                System.assertEquals('Could not find Monitored Environment record with ID: ', e.getMessage());
            }

            System.assertEquals(true, exceptionThrown);

            // Valid use case
            try {
                exceptionThrown = false;

                copado__Environment__c environment = new copado__Environment__c(
                    Name = 'Test environment 1',
                    copado__Type__c = 'Sandbox',
                    copado__Org_ID__c = '123456789012345678'
                );

                insert environment;

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

                Monitored_Environments__c monitoredEnvironment = new Monitored_Environments__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID
                );

                insert monitoredEnvironment;

                MonitoredEnvironmentCallback.GetMonitoredEnvironment(monitoredEnvironment.ID);
            } catch (MonitoringException e) {
                exceptionThrown = true;
            }

            System.assertEquals(false, exceptionThrown);
        }
    }

    @isTest
    public static void GetIgnoredActions()
    {
        List<Monitoring_Ignored_Action_Types__c> types = new List<Monitoring_Ignored_Action_Types__c>
        {
            new Monitoring_Ignored_Action_Types__c(Action__c = 'Action1'),
            new Monitoring_Ignored_Action_Types__c(Action__c = 'Action2'),
            new Monitoring_Ignored_Action_Types__c(Action__c = 'Action3')
        };

        insert types;

        Set<string> uniqueTypes = MonitoredEnvironmentCallback.GetIgnoredActions();
        System.assertEquals(3, uniqueTypes.size());
    }

    @isTest
    public static void GetMonitoringLog()
    {
        System.runAs(MonitorTestHelper.getRunAsUser()){
            Boolean exceptionThrown = false;

            //Verify null environment ID exception
            try {
                exceptionThrown = false;
                MonitoredEnvironmentCallback.GetMonitoringLog('');
            } catch (MonitoringException e) {
                exceptionThrown = true;
                System.assertEquals('Could not find Monitoring Log with ID: ', e.getMessage());
            }

            System.assertEquals(true, exceptionThrown);

            //Verify valid monitored environment
            try {
                exceptionThrown = false;

                copado__Environment__c environment = new copado__Environment__c(
                    Name = 'Test environment 1',
                    copado__Type__c = 'Sandbox',
                    copado__Org_ID__c = '123456789012345678'
                );

                insert environment;

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

                Monitored_Environments__c monitoredEnvironment = new Monitored_Environments__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID
                );

                insert monitoredEnvironment;

                copado__Result__c result = new copado__Result__c(
                    copado__Job_Type__c = 'setup_audit_trail'
                );

                insert result;

                Monitoring_Log__c log = new Monitoring_Log__c(
                    Environment__c = environment.ID,
                    Pipeline__c = pipeline.ID,
                    Integration_User__c = 'IntegrationUserName',
                    Monitored_Environment__c = monitoredEnvironment.ID,
                    Function_Result__c = result.ID
                );

                insert log;

                log = MonitoredEnvironmentCallback.GetMonitoringLog(log.ID);
                System.assert(log != null);

                List<Id> ids = new List<Id>{result.ID};
                MonitoredEnvironmentCallback.FlowEntryPoint(ids);
                MonitoredEnvironmentCallback.ProcessFiles(environment.Id, result);

            } catch (MonitoringException e) {
                exceptionThrown = false;
            }

            System.assertEquals(false, exceptionThrown);
        }
    }
}
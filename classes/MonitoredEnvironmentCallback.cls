public class MonitoredEnvironmentCallback {

    @testVisible
    private static string Test_FileBody;

    @testVisible
    private static string IntegrationUserFullName;

    @InvocableMethod
    public static void FlowEntryPoint(List<string> ids)
    {
        copado__Result__c result = [SELECT ID, copado__ParentId__c,copado__Result_Data__c, copado__Job_ID__c
                                    FROM    copado__Result__c
                                    WHERE ID in :ids
                                    LIMIT 1];


        Monitoring_Log__c monitoringLog = GetMonitoringLog(result.copado__Job_ID__c);
        Monitored_Environments__c monitoredEnvironment = GetMonitoredEnvironment(monitoringLog.Monitored_Environment__c);

        try {
            ProcessFiles(monitoringLog.Environment__c,result);

            LogSuccess(monitoringLog,monitoredEnvironment);

        } catch (Exception e) {
            
            LogError(monitoringLog,monitoredEnvironment,e.getMessage(), e.getStackTraceString());
        }
    }

    private static string BuildErrorMessage(string errorMessage, string errorStackTrace)
    {
        string error = 'Message: ' + errorMessage + '\n';
        error += 'Stack: ' + errorStackTrace + '\n';
    
        return error;
    }

    @testVisible
    private static void LogSuccess(Monitoring_Log__c monitoringLog, Monitored_Environments__c monitoredEnvironment)
    {
        monitoringLog.End_Date__c = DateTime.now();
        monitoringLog.Status__c = 'Success';
        update monitoringLog;

        monitoredEnvironment.Last_Successful_Scan__c = DateTime.now();
        monitoredEnvironment.Last_Scan_Status__c = 'Success';
        monitoredEnvironment.Last_Monitoring_Log__c = monitoringLog.ID;
        update monitoredEnvironment;
    }

    @testVisible
    private static void LogError(Monitoring_Log__c monitoringLog, Monitored_Environments__c monitoredEnvironment, string errorMessage, string errorStackTrace)
    {
        monitoredEnvironment.Last_Scan_Status__c = 'Failed';
        monitoredEnvironment.Last_Monitoring_Log__c = monitoringLog.ID;
        update monitoredEnvironment;

        monitoringLog.Error_Message__c = BuildErrorMessage(errorMessage,errorStackTrace);
        monitoringLog.End_Date__c = DateTime.now();
        monitoringLog.Status__c = 'Failed';
        update monitoringLog;
    }

    public static void ProcessFiles(string environmentId,copado__Result__c result)
    {
        List<ContentDocumentLink> files = [SELECT ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink Where LinkedEntityId = :result.id ORDER BY ContentDocument.Title DESC];
        
        for(ContentDocumentLink file : files)
        {
            switch on file.ContentDocument.Title.trim()
            {
                when 'userDetails.json' {
                    ProcessUserDetails(file.ContentDocumentId);
                }
                when 'impersonations.json' {
                    ProcessImpersonations(environmentId,result.copado__Job_ID__c,file.ContentDocumentId);
                }
                when 'metadatachanges.json' {
                    ProcessMetadataChanges(environmentId,result.copado__Job_ID__c,file.ContentDocumentId);
                }
            }
           
        }
        
    }

    @testVisible
    private static void ProcessUserDetails(string contentDocumentId)
    {
        string fileBody = GetFileBody(contentDocumentId);
        if(fileBody == null)
        {
            throw new MonitoringException('Could not get file body for user details');
        }

        // Deserialize the list of invoices from the JSON string.
        MonitoringIntegrationUserResult deserializedResults = 
          (MonitoringIntegrationUserResult)JSON.deserialize(fileBody, MonitoringIntegrationUserResult.class);

        if(deserializedResults == null)
        {
            throw new MonitoringException('Could not deserialize impersonation file body');
        }

        if(deserializedResults.records.size() == 0)
        {
            throw new MonitoringException('Could not find integration user\'s full name');
        }

        IntegrationUserFullName = deserializedResults.records[0].Name;
    }

    @testVisible
    private static void ProcessMetadataChanges(string environmentId, string monitoredEnvironmentId, string contentDocumentId)
    {
        string fileBody = GetFileBody(contentDocumentId);
        if(fileBody == null)
        {
            throw new MonitoringException('Could not get file body for metadata changes');
        }

        string pipelineId = GetPipeline(environmentId);

        Set<string> ignoredActions = GetIgnoredActions();

        // Deserialize the list of invoices from the JSON string.
        MonitoringMetadataChangesResult deserializedResults = 
          (MonitoringMetadataChangesResult)JSON.deserialize(fileBody, MonitoringMetadataChangesResult.class);

        if(deserializedResults == null)
        {
            throw new MonitoringException('Could not deserialize impersonation file body');
        }

        List<Monitoring_Metadata_Change_Alert__c> alerts = new List<Monitoring_Metadata_Change_Alert__c>();
        for(MonitoringMetadataChangesResult.MonitoringRecord record : deserializedResults.records)
        {
            //Ignore system updates
            if(record.CreatedBy == null)
            {
                continue;
            }

            if(ignoredActions.contains(record.Action))
            {
                continue;
            }

            Monitoring_Metadata_Change_Alert__c alert = new Monitoring_Metadata_Change_Alert__c(
                Action__c = record.Action,
                Event__c = record.Display,
                Display_Name__c = record.CreatedBy.Name,
                Delegate_User__c = record.DelegateUser,
                Environment__c = environmentId,
                Event_Date__c = record.CreatedDate,
                External_ID__c = environmentId + '|' + record.ID,
                Username__c = record.CreatedBy.Username,
                Section__c = record.Section,
                Pipeline__c = pipelineId
            );

            alerts.add(alert);
        }

        upsert alerts External_ID__c;
    }

    @testVisible
    private static void ProcessImpersonations(string environmentId, string monitoredEnvironmentId, string contentDocumentId)
    {
        string fileBody = GetFileBody(contentDocumentId);
        if(fileBody == null)
        {
            throw new MonitoringException('Could not get file body for impersonations');
        }

        string pipelineId = GetPipeline(environmentId);

        // Deserialize the list of invoices from the JSON string.
        MonitoringImpersonationResult deserializedResults = 
          (MonitoringImpersonationResult)JSON.deserialize(fileBody, MonitoringImpersonationResult.class);

        if(deserializedResults == null)
        {
            throw new MonitoringException('Could not deserialize impersonation file body');
        }

        List<Monitoring_Impersonation_Alert__c> alerts = new List<Monitoring_Impersonation_Alert__c>();
        for(MonitoringImpersonationResult.MonitoringImpersonationRecord record : deserializedResults.records)
        {
            //Ignore any impersonations that are not the impersonation user.
            if(!record.Display.containsIgnoreCase(IntegrationUserFullName))
            {
                continue;
            }

            Monitoring_Impersonation_Alert__c alert = new Monitoring_Impersonation_Alert__c(
                Display__c = record.Display,
                Display_Name__c = record.CreatedBy.Name,
                Environment__c = environmentId,
                Event_Date__c = record.CreatedDate,
                External_ID__c = environmentId + '|' + record.ID,
                Username__c = record.CreatedBy.Username,
                Pipeline__c = pipelineId
            );

            alerts.add(alert);
        }

        upsert alerts External_ID__c;
    }

    @testVisible
    private static Monitoring_Log__c GetMonitoringLog(string monitoringLogId)
    {
        List<Monitoring_Log__c> logs = [SELECT Environment__c, Monitored_Environment__c
                                         FROM   Monitoring_Log__c
                                         WHERE  ID = :monitoringLogId
                                         LIMIT 1];

        if(logs.size() == 0)
        {
            throw new MonitoringException('Could not find Monitoring Log with ID: ' + monitoringLogId);
        }

        return logs[0];
    }

    @testVisible
    private static Set<string> GetIgnoredActions()
    {
        List<Monitoring_Ignored_Action_Types__c> records = [SELECT Action__c FROM Monitoring_Ignored_Action_Types__c];

        Set<string> actions = new Set<string>();
        for(Monitoring_Ignored_Action_Types__c record : records)
        {
            if(actions.Contains(record.Action__c))
            {
                continue;
            }

            actions.add(record.Action__c);
        }

        return actions;
    }

    private static string GetFileBody(string contentDocumentId)
    {
        if(Test.isRunningTest())
        {
            return Test_FileBody;
        }

        ContentVersion latestVersion = [SELECT VersionData 
                                        FROM ContentVersion 
                                        WHERE ContentDocumentId = :contentDocumentId 
                                            AND IsLatest = true
                                        LIMIT 1];

        return latestVersion.VersionData.toString();
    }

    @testVisible
    private static Monitored_Environments__c GetMonitoredEnvironment(string monitoredEnvironmentId)
    {
        if(monitoredEnvironmentId == null)
        {
            throw new MonitoringException('Function was not able to link Monitored Environment ID correctly.');
        }

        List<Monitored_Environments__c> environments = [SELECT ID, Environment__c 
                                                                FROM Monitored_Environments__c 
                                                                WHERE ID = :monitoredEnvironmentId 
                                                                LIMIT 1];

        if(environments.size() == 0)
        {
            throw new MonitoringException('Could not find Monitored Environment record with ID: ' + monitoredEnvironmentId);
        }

        return environments[0];
    }

    public static string GetPipeline(string environmentId)
    {
        List<copado__Deployment_Flow_Step__c> connections = [SELECT copado__Deployment_Flow__c
                                                           FROM   copado__Deployment_Flow_Step__c
                                                           WHERE  copado__Source_Environment__c = :environmentId
                                                            OR copado__Destination_Environment__c = :environmentId];

        Set<string> pipelineIds = new Set<string>();
        for(copado__Deployment_Flow_Step__c connection : connections)
        {
            if(pipelineIds.contains(connection.copado__Deployment_Flow__c))
            {
                continue;
            }

            pipelineIds.add(connection.copado__Deployment_Flow__c);
        }

        if(pipelineIds.size() == 0)
        {
            throw new MonitoringException('Environment is not connected to a Pipeline: ' + environmentId);
        }

        return (new list<string>(pipelineIds))[0];
    }
}
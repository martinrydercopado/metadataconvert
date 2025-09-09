public class MonitoredEnvironmentInitiator {
    
    @testVisible
    private static List<string> testingFunctionResults;

    @InvocableMethod
    public static void FlowEntryPoint(List<string> ids)
    {
        ScanEnvironments(ids);
    }

    public static void ScanEnvironments(List<string> ids)
    {
        List<Monitored_Environments__c> monitoredEnvironments = GetMonitoredEnvironments(ids);

        List<string> validatedEnvironmentIds = ValidateEnvironmentIds(ids,monitoredEnvironments);
        
        Map<string,string> environmentMonitoredEnvironments = MapMonitoriedEnvironments(monitoredEnvironments);
        Map<string,string> environmentUserNames = GetDefaultCredentialUsernames(validatedEnvironmentIds);
        Map<string,string> environmentPipelines = GetPipelinesForEnvironments(validatedEnvironmentIds);

        Map<string,string> resultForEnvironments = new Map<string,string>();
        Map<string,Monitoring_Log__c> logs = new Map<string,Monitoring_Log__c>();
        for(string environmentId :validatedEnvironmentIds)
        {
            string integrationUserName = environmentUserNames.get(environmentId);
            string monitoredEnvironmentId = environmentMonitoredEnvironments.get(environmentId);

            List<string> results = ExecuteFunction(integrationUserName,environmentId);
            if(results.size() == 0)
            {
                throw new MonitoringException('Invoking Copado Function did not return any results for Environment: ' + environmentId + ' Integration User:' + integrationUserName);
            }

            for(string result : results)
            {
                System.debug('Result: ' + result);
            }

            string resultId = results[0];
            resultForEnvironments.put(resultId,environmentId);

            string pipelineId = environmentPipelines.get(environmentId);
            
            logs.put(environmentId,new Monitoring_Log__c(
                Environment__c = environmentId,
                Monitored_Environment__c = monitoredEnvironmentId,
                Integration_User__c = integrationUserName,
                Start_Date__c = DateTime.now(),
                Pipeline__c = pipelineId,
                Function_Result__c = resultId
            ));
        }

        insert logs.values();

        UpdateResults(logs,resultForEnvironments);

    }

    private static Map<string, string> MapMonitoriedEnvironments(List<Monitored_Environments__c> monitoredEnvironments)
    {
        Map<string, string> environmentMap = new Map<string,string>();

        for(Monitored_Environments__c environment : monitoredEnvironments)
        {
            environmentMap.put(environment.Environment__c, environment.ID);
        }

        return environmentMap;
    }

    @testVisible
    private static Map<string,string> GetDefaultCredentialUsernames(List<string> validateEnvironmentIds)
    {
        List<copado__Org__c> orgCredentials = [SELECT ID, copado__Username__c, copado__Environment__c
                                               FROM copado__Org__c 
                                               WHERE copado__Environment__c IN :validateEnvironmentIds AND copado__Default_Credential__c = true];

        Set<string> idSet = new Set<string>(validateEnvironmentIds);
        Map<string,string> environmentUsernames = new Map<string,string>();

        for(copado__Org__c credential : orgCredentials)
        {
            if(!idSet.contains(credential.copado__Environment__c) || environmentUsernames.containsKey(credential.copado__Environment__c))
            {
                continue;
            }

            idSet.remove(credential.copado__Environment__c);
            environmentUsernames.put(credential.copado__Environment__c,credential.copado__Username__c);
        }

        //Build a comma separated list and throw exception
        if(idSet.size() > 0)
        {
            throw new MonitoringException('Could not find Default Credential records with IDs: ' + CommaSeperateIds(idSet));
        }

        return environmentUsernames;
    }

    private static Map<string,string> GetPipelinesForEnvironments(List<string> validateEnvironmentIds)
    {
        //Check for both source OR destination because Production environments won't be sources.
        List<copado__Deployment_Flow_Step__c> connections = [SELECT copado__Deployment_Flow__c,copado__Source_Environment__c,copado__Destination_Environment__c
                                                             FROM   copado__Deployment_Flow_Step__c
                                                             WHERE  copado__Source_Environment__c IN :validateEnvironmentIds
                                                                OR copado__Destination_Environment__c IN :validateEnvironmentIds];


        Set<string> idSet = new Set<string>(validateEnvironmentIds);
        Map<string,string> environmentPipelines = new Map<string,string>();

        for(copado__Deployment_Flow_Step__c connection : connections)
        {
            string environmentId = '';
            if(idSet.contains(connection.copado__Source_Environment__c))
            {
                environmentId = connection.copado__Source_Environment__c;
            }

            if(idSet.contains(connection.copado__Destination_Environment__c))
            {
                environmentId = connection.copado__Destination_Environment__c;
            }

            if(environmentPipelines.containsKey(environmentId) || !idSet.contains(environmentId))
            {
                continue;
            }

            idSet.remove(environmentId);
            environmentPipelines.put(environmentId,connection.copado__Deployment_Flow__c);
        }

        //Build a comma separated list and throw exception
        if(idSet.size() > 0)
        {
            throw new MonitoringException('Could not find Pipeline records with IDs: ' + CommaSeperateIds(idSet));
        }

        return environmentPipelines;
    }

    private static void UpdateResults(Map<string,Monitoring_Log__c> logs, Map<string,string> resultForEnvironments)
    {
        List<copado__Result__c> results = [SELECT ID 
                                           FROM copado__Result__c 
                                           WHERE ID IN :resultForEnvironments.keySet() 
                                           LIMIT 1];
        
        for(copado__Result__c result : results)
        {
            string environmentId = resultForEnvironments.get(result.ID);
            Monitoring_Log__c log = logs.get(environmentId);

            result.copado__job_id__c = log.ID;
        }

        update results;
    }

    private static List<Monitored_Environments__c> GetMonitoredEnvironments(List<string> monitoredEnvironmentIds)
    {
        return [SELECT  ID, Environment__c
                FROM     Monitored_Environments__c
                WHERE    ID IN :monitoredEnvironmentIds];        
    }

    private static List<string> ValidateEnvironmentIds(List<string> ids, List<Monitored_Environments__c> monitoredEnvironments)
    {
        Set<string> idSet = new Set<string>(ids);
        List<string> environmentIds = new List<string>();

        for(Monitored_Environments__c environment : monitoredEnvironments)
        {
            if(!idSet.contains(environment.ID))
            {
                continue;
            }

            idSet.remove(environment.ID);
            environmentIds.add(environment.Environment__c);
        }

        //Build a comma separated list and throw exception
        if(idSet.size() > 0)
        {
            throw new MonitoringException('Could not find Monitored Environment records with IDs: ' + CommaSeperateIds(idSet));
        }

        return environmentIds;
    }

    private static List<string> ExecuteFunction(string integrationUserName, string environmentId)
    {
        if(Test.isRunningTest())
        {
            return testingFunctionResults;
        }

        copado.RunCopadoFunction.InvocableVariables invocableVariable = new copado.RunCopadoFunction.InvocableVariables();
        invocableVariable.functionApiName = 'setup_audit_trail';
        invocableVariable.parametersJSON = '[{"name":"IntegrationUsername","value":"' + integrationUserName + '"},{"name":"SessionID","value":"{$Context.Credential.SessionId}"},{"name":"Endpoint","value":"{$Context.Credential.Endpoint}"}]';
        invocableVariable.contextId = environmentId;

        List<copado.RunCopadoFunction.InvocableVariables> invocableVariables = new List<copado.RunCopadoFunction.InvocableVariables>{invocableVariable};
        return copado.RunCopadoFunction.execute(invocableVariables);
    }

    private static string CommaSeperateIds(Set<string> ids)
    {
        string commaSeperatedList = '';
        for(string id : ids)
        {
            if(commaSeperatedList.length() > 0)
            {
                commaSeperatedList += ', ' + id;
                continue;
            }

            commaSeperatedList = id;
        }

        return commaSeperatedList;
    }    
}
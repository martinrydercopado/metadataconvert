global class MonitoringScheduledJob implements Schedulable, Database.AllowsCallouts  {

    @testVisible
    private static List<string> Test_EnvironmentsScanned = new List<string>();

    global void execute(SchedulableContext ctx) {
        RunScheduledScans();
    }

    public void RunScheduledScans()
    {
        List<Monitored_Environments__c> environments = [SELECT  ID
                                                        FROM    Monitored_Environments__c
                                                        WHERE   Schedule__c = 'Use Apex Job Schedule'];

        for(Monitored_Environments__c environment : environments)
        {
            try {
                ExecuteScanFunctions(environment.ID);
            } 
            catch (Exception e) 
            {
                System.debug('Could not start scan of monitored id: ' + environment.ID);
                System.debug(e);
            }
        }
    }

    @future(callout=true)
    public static void ExecuteScanFunctions(string monitoredEnvironmentId)
    {
        if(Test.isRunningTest())
        {
            Test_EnvironmentsScanned.add(monitoredEnvironmentId);
            return;
        }

        MonitoredEnvironmentInitiator.ScanEnvironments(new List<string> { monitoredEnvironmentId });
    }
}
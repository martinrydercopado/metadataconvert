global class MonitoringPostInstallClass implements InstallHandler {
    global void onInstall(InstallContext context) {
      try{
          copado.CreateStandardRecords.execute('MonitorExtensionBundle');
      }
      catch (Exception e){
          System.debug('Could not execute post intall script' + e);
      }
    }
}
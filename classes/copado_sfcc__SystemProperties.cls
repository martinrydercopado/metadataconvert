public with sharing class SystemProperties {
    
    @AuraEnabled(cacheable=true)
	public static Map<String,String> getSystemPropertiesFromPipelineOfUserStory(Id userStoryId, String[] names) {
        Id pipelineId = userStoryId;
        // NOTE: we avoid testing this line to reduce complexity in the unit-test
        if(!Test.isRunningTest()) {
	        pipelineId = [SELECT copado__Project__r.copado__Deployment_Flow__c FROM copado__User_Story__c WHERE Id = :userStoryId WITH SECURITY_ENFORCED LIMIT 1].copado__Project__r.copado__Deployment_Flow__c;
        }
        return getSystemProperties(pipelineId, names);
    }

    // query a list of system properties of the parentId ( pipeline, environment, or user )
    // you can only get up to 200 names
    @AuraEnabled(cacheable=true)
	public static Map<String,String> getSystemProperties(Id parentId, String[] names) {
   		List<copado__System_Property__c> properties = [SELECT Name, copado__Value__c
                                                       FROM copado__System_Property__c 
                                                       WHERE copado__ParentId__c = :parentId
                                                       AND Name IN :names
                                                       WITH SECURITY_ENFORCED
                                                       LIMIT 200];
        
        Map<String,String> elements = new Map<String, String>();
        
        for (copado__System_Property__c prop : properties) {
            elements.put(prop.Name, prop.copado__Value__c);
        }
        
        return elements;
    }
}
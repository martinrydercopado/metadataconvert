@isTest
public class SystemPropertiesTest {
    @isTest public static void getSystemPropertiesTest() {
        String parentId = UserInfo.getUserId();
        String name = 'test_property';
        String value = 'value';

        copado__System_Property__c prop = new copado__System_Property__c(
            Name=name,
            copado__API_Name__c=name,
            copado__Value__c = value,
            copado__ParentId__c = parentId
        );
        insert prop;
        
        Map<String,String> props = SystemProperties.getSystemProperties(
            parentId,
            new String[]{name, 'nonexisting'}
        );

        System.debug(props);

        System.assertEquals(value, props.get(name));
        
        SystemProperties.getSystemPropertiesFromPipelineOfUserStory(parentId, new String[]{name, 'test_property'});
    }
}
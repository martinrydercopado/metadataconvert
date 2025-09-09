public with sharing class GetContentDocument {

    @AuraEnabled(cacheable=false)
    public static String getChangesFromUserStory(String parentId) {
        String namePattern = 'metadata-cache.json';
        copado__User_Story__c userStory = [
            SELECT
                Id,
                copado__Environment__c
            FROM
                copado__User_Story__c
            WHERE
                Id = :parentId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        List<ContentDocumentLink> links = [
            SELECT ContentDocument.Title, ContentDocument.LatestPublishedVersionId,
                ContentDocument.LatestPublishedVersion.ContentSize
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :userstory.copado__Environment__c AND ContentDocument.Title like :namePattern
            WITH SECURITY_ENFORCED ORDER BY ContentDocument.ContentModifiedDate DESC LIMIT 1
        ];

        Integer latestVersionSize = links.isEmpty()
            ? 0
            : links[0].ContentDocument.LatestPublishedVersion.ContentSize;

        if( latestVersionSize > 0 && latestVersionSize <= 2000000 ) { // limit to 2mb...
            Blob versionData = [SELECT VersionData FROM ContentVersion WHERE Id = :links[0].ContentDocument.LatestPublishedVersionId WITH SECURITY_ENFORCED].VersionData;

            return versionData.toString();
        } else {
            return '[]';
        }
    }
}
@JsonAccess(serializable='always' deserializable='always')
global with sharing class ActionResponse {
    global ActionResponse() {}
    global ActionResponse(String message) { this.message = message; }
    global ActionResponse(String message, String error) { this.message = message; this.error=error;}
    global ActionResponse(String message, String error, String link) { this.message = message; this.error=error; this.link=link;}

    @AuraEnabled
    global String message;
    @AuraEnabled
    global String error;
    @AuraEnabled
    global String link;
}
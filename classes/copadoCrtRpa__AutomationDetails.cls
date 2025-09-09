public with sharing class AutomationDetails {
    @InvocableVariable
    public String suiteId;

    @InvocableVariable
    public String projectId;

    @InvocableVariable
    public String executionId;

    @InvocableVariable
    public String loginUrl;

    public AutomationDetails(String projectId, String suiteId, String executionId) {
        this.executionId = executionId;
        this.suiteId = suiteId;
        this.projectId = projectId;
    }

    public AutomationDetails(String projectId, String suiteId) {
        this.suiteId = suiteId;
        this.projectId = projectId;
    }

    public AutomationDetails executionId(String executionId) {
        this.executionId = executionId;

        return this;
    }

    public AutomationDetails loginUrl(String endpoint, String sessionId) {
        Url url = new Url(endpoint);
        this.loginUrl = 'https://'+url.getHost()+'/secur/frontdoor.jsp?sid='+sessionId+'&retURL=lightning/page/home';
        System.debug(this.loginUrl);

        return this;
    }
}
@isTest
global class ApiMock implements HttpCalloutMock {
    private static final String CONTENT_TYPE = 'Content-Type';
    private static final String CONTENT_APP_JSON = 'application/json';

    private String projectId;
    private String suiteId;
    private String executionId;
    private String status = 'succeeded';

    // CTOR
    public ApiMock(String projectId, String suiteId) {
        this.projectId = projectId;
        this.suiteId = suiteId;
    }

    public ApiMock(String projectId, String suiteId, String executionId) {
        this.projectId = projectId;
        this.suiteId = suiteId;
        this.executionId = executionId;
    }

    public ApiMock status(String status) {
        this.status = status;

        return this;
    }

    public ApiMock executionId(String executionId) {
        this.executionId = executionId;

        return this;
    }

    global HttpResponse respond(HTTPRequest req){
        HttpResponse res = new HttpResponse();
        System.debug('Endpoint: ' + req.getEndpoint());
        if (req.getEndpoint().contains('/pace/v4/projects/'+projectId+'/jobs/'+suiteId+'/builds/'+executionId+'?polling=true')) {
            res.setBody('{"message":"message", "data":{"id":'+executionId+', "status": "'+status+'", "logReportUrl": "url", "jsonObjReport":{"status": "'+status+'"}}}');
        } else if (req.getEndpoint().contains('/pace/v4/projects/'+projectId+'/jobs/'+suiteId+'/builds')) {
            res.setBody('{"message":"message", "data":{"id":'+executionId+', "status": "'+status+'", "logReportUrl": "url", "jsonObjReport":{"status": "'+status+'"}}}');
        } else {
            System.debug('**** URL not Mocked **** ' + req.getEndpoint());
        }

        res.setStatus('OK');

        return res;
    }
}
global with sharing class FlowCustomError {
    // this method cannot be bulkified, because it will always throw exception at first
    @InvocableMethod(label='Throw Custom Flow Exception')
    global static void fail(String[] messages) {
        throw new CustomException(messages[0]);
    }
    global class CustomException extends Exception {}
}
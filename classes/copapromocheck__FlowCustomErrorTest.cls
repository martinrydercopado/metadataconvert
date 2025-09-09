@isTest
private with sharing class FlowCustomErrorTest {
    @IsTest
    static void testThrowException() {
        try{
            FlowCustomError.fail(new String[]{'custom error'});
            System.assert(false, 'We were expecting an exception');
        }catch(Exception e) {
            System.assert(e.getMessage().contains('custom error'), 'Error message is not the expected one');
        }
    }
}
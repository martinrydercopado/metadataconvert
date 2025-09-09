public with sharing class MonitoringMetadataChangesResult {
    public Integer totalSize;
    public Boolean done;
    public MonitoringRecord[] records;

    public class MonitoringRecord {
        public string ID;
        public string Action;
        public string Section;
        public string Display;
        public string DelegateUser;
        public DateTime CreatedDate;
        public CreatedBy CreatedBy;
    }

    public class CreatedBy {
        public string Name;
        public string Username;
    }
}
public class MonitoringImpersonationResult {
    public Integer totalSize;
    public Boolean done;
    public MonitoringImpersonationRecord[] records;

    public class MonitoringImpersonationRecord {
        public string ID;
        public string Display;
        public DateTime CreatedDate;
        public CreatedBy CreatedBy;
    }

    public class CreatedBy {
        public string Name;
        public string Username;
    }
}
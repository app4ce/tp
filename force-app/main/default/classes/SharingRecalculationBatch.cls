public class SharingRecalculationBatch{
    @InvocableMethod(label='Run Apex Sharing Recalculation' description='Starts Sharing Recalculation Batch job')
    public static void runBatchJob(List<Id> recordIds){
        ApexSharingRecalculation asr = new ApexSharingRecalculation(recordIds[0], true);
        Database.executeBatch(asr);
    }
}
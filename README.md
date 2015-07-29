# SFDC-FileBrowser
Visualforce Component to display combined attachments from related files. 

Example

   public List<String> childrenFiles {
		 get {
		 	return new List<String> { 'Work_Orders__r', 'Cases__r', 'Change_Orders__r' };
		 }
		 private set;
	 }
	
	 public List<String> lookupFiles {
		 get {
		 	return new List<String> { 'Originating_Opportunity__c' };
		 }
		 private set;
	 }

   <c:FileBrowser sObjectId="{!Project__c.Id}" displayChildren="{!childrenFiles}" displayLookup="{!lookupFiles}" />
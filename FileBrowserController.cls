public with sharing class FileBrowserController {
	
	public Id inputSObjectId {get; set;}
	public List<String> parentObjects {get; set;}
	public List<String> childObjects {get; set;}
	public Integer maxLines {get; set;}
	public String groupFilter {get; set;}
	public String searchStr {get; set;}
	
	public Boolean hasNext {get; private set;} 
	public Boolean hasPrevious {get; private set;} 
	public Integer offset {get; private set;}
	public String navCounter {get; private set;}
	public List<FileGroup> fileGroups {get; private set;}
	
	public List<File> files { 
		get {
			List<File> filterFiles = new List<File>();
			if (retrievedFiles == null) loadFiles();
			
			// Filter Files
			if (groupFilter == 'All') {
				filterFiles.addAll(retrievedFiles);
			} else {
				for (File f : retrievedFiles) {
					if (f.groupKey == groupFilter) filterFiles.add(f);
				}
			}
			
			// Search
			if (searchStr != '') {
				List<File> searchFiles = new List<File>();
				for (File f : filterFiles) {
					if (f.attachment.Title.contains(searchStr)) searchFiles.add(f);
				}
				filterFiles = searchFiles;
			}
			
			// Paging
			hasNext = filterFiles.size() > (offset * maxLines) + maxLines;
			hasPrevious = (offset > 0);
			List<File> pagedFiles = new List<File>();
			Integer startN = (offset * maxLines);
			Integer endN = startN;
			if (filterFiles.size() > 0) {
				do {
					pagedFiles.add(filterFiles.get(endN));
					endN++;
				} while (endN < ((offset * maxLines) + maxLines) && filterFiles.size() > endN);
			}
			navCounter = String.valueOf(startN+1) + '-' + String.valueOf(endN) + ' of ' + filterFiles.size(); 
			
			return pagedFiles;
		}
		private set;
	}

	private List<File> retrievedFiles;
	
	public FileBrowserController() {
		groupFilter = 'All';
		offset = 0;
		searchStr = '';
	}
	
	private void loadFiles() {
		
		fileGroups = new List<FileGroup>();
		fileGroups.add(new FileGroup('All', 'All'));
		fileGroups.get(0).selected = true;
		retrievedFiles = new List<File>();
		
		// Get Object Files
		SObjectType inputSObjectType = inputSObjectId.getSObjectType();
		DescribeSObjectResult inputSObjectDescribe = inputSObjectType.getDescribe();
		String objectNameField = getObjectNameField(inputSObjectDescribe);
		retrievedFiles.addAll(queryFiles(inputSObjectDescribe, objectNameField, inputSObjectDescribe.getName(), ' Id = \'' + inputSObjectId + '\'', inputSObjectDescribe.getLabel()));
		fileGroups.add(new FileGroup(inputSObjectDescribe.getLabel(), inputSObjectDescribe.getName()));
		
		// Get Lookup Relationship Files
		Map<String, DescribeFieldResult> relationshipFieldMap = getLookupFieldMap(inputSObjectDescribe);
		for (String parentObject : parentObjects) {
			DescribeFieldResult relationship = relationshipFieldMap.get(parentObject);
			if (relationship != null) {
				for (SObjectType relationshipObjectType : relationship.getReferenceTo()) {
					DescribeSObjectResult relationshipDescribe = relationshipObjectType.getDescribe(); 
					String relationshipObjectName = getObjectNameField(relationshipDescribe);
				
					// Add Files from Lookup Objects
					List<File> addFiles = queryFiles(relationshipDescribe, relationshipObjectName, relationship.getName(), 
						' Id in (select ' + relationship.getName() + ' from ' + inputSObjectDescribe.getName() + ' where Id = \'' + inputSObjectId + '\')', 
						relationship.getLabel());
					if (!addFiles.isEmpty()) { 
						retrievedFiles.addAll(addFiles);
						fileGroups.add(new FileGroup(relationship.getLabel(), relationship.getName()));
					}
				}
			}
		}
		
		// Get Child Object Files
		Map<String, ChildRelationship> childRelationships = getChildRelationshipMap(inputSObjectDescribe);
		
		for (String childObject : childObjects) {
			ChildRelationship relationship = childRelationships.get(childObject);
			if (relationship != null) {
				
				// Get Object Information
				DescribeSObjectResult describeChild = relationship.getChildSObject().getDescribe();
				String childNameField = getObjectNameField(describeChild);
				
				// Add Files from Child Objects
				List<File> addFiles = queryFiles(describeChild, childNameField, relationship.getRelationshipName(), relationship.getField() + ' = \'' + inputSObjectId + '\'',
					describeChild.getLabelPlural());
				if (!addFiles.isEmpty()) { 
					retrievedFiles.addAll(addFiles);
					fileGroups.add(new FileGroup(describeChild.getLabelPlural(), relationship.getRelationshipName()));
				}
			}	
		}
	}
	
	public PageReference filterGroup() {
		offset = 0;
		for (FileGroup fg : fileGroups) {
			fg.selected = false;
			if (groupFilter == fg.key) fg.selected = true;
		}
		return null;
	}
	
	public PageReference search() {
		return null;
	}
	
	public PageReference next() {
		offset++;
		return null;
	}
	
	public PageReference previous() {
		offset--;
		return null;
	}
	
	private String getObjectNameField(DescribeSObjectResult sObjectDescribe) {
		Map<String, SObjectField> childFieldMap = sObjectDescribe.fields.getMap();
		for (String fieldKey : childFieldMap.keyset()) {
			DescribeFieldResult field = childFieldMap.get(fieldKey).getDescribe();
			if (field.isNameField()) return field.getName();
		}
		return null;
	}
	
	private List<File> queryFiles(DescribeSObjectResult sObjectDescribe, String nameField, String groupKey, String filter, String locationPrefix) {
		
		List<File> files = new List<File>();
		String query = 'select Id, ' + nameField + ', (select Id, Title, ContentUrl, FileType, CreatedDate from CombinedAttachments) from ' 
			+ sObjectDescribe.getName() + ' where ' + filter;
		List<SObject> objects = Database.query(query);
		
		for (SObject obj : objects) {
			if (obj.getSObjects('CombinedAttachments') != null) {
				for (CombinedAttachment attachment : (List<CombinedAttachment>)obj.getSObjects('CombinedAttachments')) {
					files.add(new File(attachment, locationPrefix + ' > ' + obj.get(nameField), groupKey));
				}
			}
		}
		return files;
	}
	
	private Map<String, DescribeFieldResult> getLookupFieldMap(DescribeSObjectResult sObjectDescribe) {
		Map<String, SObjectField> childFieldMap = sObjectDescribe.fields.getMap();
		Map<String, DescribeFieldResult> relationshipMap = new Map<String, DescribeFieldResult>();	
		for (String fieldKey : childFieldMap.keyset()) {
			DescribeFieldResult field = childFieldMap.get(fieldKey).getDescribe();
			if (field.getReferenceTo() != null) relationshipMap.put(field.getName(), field);
		}
		return relationshipMap;
	}
	
	private Map<String, ChildRelationship> getChildRelationshipMap(DescribeSObjectResult sObjectDescribe) {
		Map<String, ChildRelationship> relationshipMap = new Map<String, ChildRelationship>();	
		for (ChildRelationship childRelationship : sObjectDescribe.getChildRelationships()) { 
			if (childRelationship.getRelationshipName() != null) {
				relationshipMap.put(childRelationship.getRelationshipName(), childRelationship);
			}
		}
		return relationshipMap;
	}
	
	public class FileGroup {
		
		public String name {get; private set;}
		public String key {get; private set;}
		public Boolean selected {get; private set;}
		
		public FileGroup() {
		}
		
		public FileGroup(String name, String key) {
			this.name = name;
			this.key = key;
			this.selected = false;
		}
	}
	
	public class File {
		
		public String location {get; private set;}
		public String groupKey {get; private set;}
		public CombinedAttachment attachment {get; private set;}
		
		public File(CombinedAttachment attachment, String location, String groupKey) {
			this.attachment = attachment;
			this.location = location;
			this.groupKey = groupKey;
		}	
		
	}
	
	
	


}
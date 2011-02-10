package com.knowgate.berkeleydb;

import com.sleepycat.db.DatabaseException;
import com.sleepycat.db.SecondaryConfig;
import com.sleepycat.db.SecondaryCursor;
import com.sleepycat.db.SecondaryDatabase;
import com.sleepycat.db.SecondaryKeyCreator;
import com.sleepycat.db.SecondaryMultiKeyCreator;

public class DBIndex {
  private String sTable;
  private String sColumn;
  private String sRelation;
  private SecondaryDatabase oSdb;
  
  public DBIndex(String sTableName, String sColumnName, String sRelationType) {
  	sTable = sTableName;
  	sColumn = sColumnName;
  	sRelation = sRelationType;
  	oSdb = null;
  }

  public String getName() {
  	return sColumn;
  }
  
  public String getRelationType() {
  	return sRelation;
  }

  public void open(SecondaryDatabase oSecDb) {
  	oSdb = oSecDb;
  }
  
  public void close() throws DatabaseException {
  	if (oSdb!=null) {
  	  oSdb.close();
  	  oSdb=null;
  	}
  }

  public boolean isClosed() {
    return oSdb==null;
  }
  
  public SecondaryCursor getCursor() throws DatabaseException {
  	return oSdb.openSecondaryCursor(null, null);
  }
  
}
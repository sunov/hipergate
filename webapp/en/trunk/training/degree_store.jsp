﻿<%@ page import="java.io.IOException,java.net.URLDecoder,java.sql.SQLException,com.knowgate.jdc.JDCConnection,com.knowgate.dataobjs.*,com.knowgate.acl.*,com.knowgate.hipergate.DBLanguages,com.knowgate.training.EducationDegree" language="java" session="false" contentType="text/html;charset=UTF-8" %>
<%@ include file="../methods/page_prolog.jspf" %><%@ include file="../methods/dbbind.jsp" %><%@ include file="../methods/cookies.jspf" %><%@ include file="../methods/authusrs.jspf" %><%@ include file="../methods/clientip.jspf" %><%@ include file="../methods/reqload.jspf" %><jsp:useBean id="GlobalCacheClient" scope="application" class="com.knowgate.cache.DistributedCachePeer"/><%
/*
  Copyright (C) 2003-2009  Know Gate S.L. All rights reserved.
                           C/Oña, 107 1º2 28050 Madrid (Spain)

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. The end-user documentation included with the redistribution,
     if any, must include the following acknowledgment:
     "This product includes software parts from hipergate
     (http://www.hipergate.org/)."
     Alternately, this acknowledgment may appear in the software itself,
     if and wherever such third-party acknowledgments normally appear.

  3. The name hipergate must not be used to endorse or promote products
     derived from this software without prior written permission.
     Products derived from this software may not be called hipergate,
     nor may hipergate appear in their name, without prior written
     permission.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  You should have received a copy of hipergate License with this code;
  if not, visit http://www.hipergate.org or mail to info@hipergate.org
*/

  response.addHeader ("Pragma", "no-cache");
  response.addHeader ("cache-control", "no-store");
  response.setIntHeader("Expires", 0);

  final String PAGE_NAME = "degree_store";

  if (autenticateSession(GlobalDBBind, request, response)<0) return;
      
  String gu_workarea = request.getParameter("gu_workarea");
  String id_user = getCookie (request, "userid", null);
  
  String gu_degree = request.getParameter("gu_degree");

  String sOpCode = gu_degree.length()>0 ? "NDGR" : "MDGR";
      
  EducationDegree oObj = new EducationDegree();

  JDCConnection oConn = null;
  
  try {
    oConn = GlobalDBBind.getConnection(PAGE_NAME); 
  
    loadRequest(oConn, request, oObj);

    oConn.setAutoCommit (false);
    
    oObj.store(oConn);

    DBAudit.log(oConn, oObj.ClassId, sOpCode, id_user, oObj.getString(DB.gu_degree), null, 0, 0, request.getParameter("tp_degree"), request.getParameter("nm_degree"));
    
    oConn.commit();
    oConn.close(PAGE_NAME);
  }
  catch (SQLException e) {
    disposeConnection(oConn,PAGE_NAME);
    oConn = null;

    if (com.knowgate.debug.DebugFile.trace) {
      com.knowgate.dataobjs.DBAudit.log ((short)0, "CJSP", sUserIdCookiePrologValue, request.getServletPath(), "", 0, request.getRemoteAddr(), e.getClass().getName(), e.getMessage());
    }
    response.sendRedirect (response.encodeRedirectUrl ("../common/errmsg.jsp?title=SQLException&desc=" + e.getLocalizedMessage() + "&resume=_back"));
  }
  
  if (null==oConn) return;
  
  oConn = null;
  
  final int nLangs = DBLanguages.SupportedLanguages.length;
  for (int l=0; l<nLangs; l++) {
    GlobalCacheClient.expire("k_education_degree["+gu_workarea+","+DBLanguages.SupportedLanguages[l]+"]");
  }
  
  response.sendRedirect (response.encodeRedirectUrl ("degree_lookup.jsp"));

%><%@ include file="../methods/page_epilog.jspf" %>
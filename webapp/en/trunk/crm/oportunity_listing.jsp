<%@ page import="java.util.HashMap,java.net.URLDecoder,java.sql.SQLException,java.util.Date,java.text.SimpleDateFormat,com.knowgate.jdc.*,com.knowgate.acl.*,com.knowgate.dataobjs.*,com.knowgate.hipergate.DBLanguages,com.knowgate.misc.Gadgets" language="java" session="false" contentType="text/html;charset=UTF-8" %>
<%@ include file="../methods/dbbind.jsp" %><%@ include file="../methods/cookies.jspf" %><%@ include file="../methods/nullif.jspf" %><%@ include file="../methods/authusrs.jspf" %>
<jsp:useBean id="GlobalCacheClient" scope="application" class="com.knowgate.cache.DistributedCachePeer"/><%
/*
  Copyright (C) 2003  Know Gate S.L. All rights reserved.
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

  SimpleDateFormat oSimpleDate = new SimpleDateFormat("yyyy-MM-dd");

  String sLanguage = getNavigatorLanguage(request);

  String sSkin = getCookie(request, "skin", "default");
  boolean bCampaignsEnabled = ((Integer.parseInt(getCookie(request, "appmask", "0")) & (1<<18))!=0);

  String id_user = getCookie (request, "userid", null);
  String id_domain = getCookie(request,"domainid","");
  String n_domain = getCookie(request,"domainnm",""); 
  String gu_workarea = getCookie(request,"workarea",null); 

  String sWhere = nullif(request.getParameter("where")).trim();
  String sContactId = nullif(request.getParameter("gu_contact"));
  String sCompanyId = nullif(request.getParameter("gu_company"));
  String sStatusId = nullif(request.getParameter("id_status"));  
  String sField = nullif(request.getParameter("field")).trim();      
  String sFind = nullif(request.getParameter("find")); 
  String sCampaignId = nullif(request.getParameter("gu_campaign"));
  String sSalesManId = nullif(request.getParameter("gu_sales_man"));

  String sCampaignsLookUp = "";
  String sStatusLookUp = "";
  String sSalesMenLookUp = "";
  HashMap oStatusLookUp = null;
  int iOportunityCount = 0;

  boolean bIsGuest = isDomainGuest (GlobalCacheClient, GlobalDBBind, request, response);
  boolean bIsAdmin = isDomainAdmin (GlobalCacheClient, GlobalDBBind, request, response);
  
  DBSubset oSalesMen = null;
  DBSubset oOportunities = null;
  DBSubset oCampaigns = new DBSubset (DB.k_campaigns, DB.gu_campaign+","+DB.nm_campaign+","+DB.bo_active, DB.gu_workarea+"=?",100);
  String sOrderBy;
  String sPrivate = null;
  int iPrivate;
  int iOrderBy;  
  int iMaxRows;
  int iSkip;
	
  if (request.getParameter("private")!=null) {
    try { iPrivate = Integer.parseInt(request.getParameter("private")); } catch (NumberFormatException nfe) { iPrivate = 0; }
  }
  else {
    iPrivate = (bIsAdmin ? 0 : 1);
  }
  
  try {
    if (request.getParameter("maxrows")!=null)
      iMaxRows = Integer.parseInt(request.getParameter("maxrows"));
    else 
      iMaxRows = Integer.parseInt(getCookie(request, "maxrows", "20"));
  }
  catch (NumberFormatException nfe) { iMaxRows = 20; }
  
  try {
    if (request.getParameter("skip")!=null)
      iSkip = Integer.parseInt(request.getParameter("skip"));      
    else
      iSkip = 0;
  }
  catch (NumberFormatException nfe) { iSkip = 0; }

  if (iSkip<0) iSkip = 0;

  if (request.getParameter("orderby")!=null)
    sOrderBy = request.getParameter("orderby");
  else
    sOrderBy = "0";   

  try {
    iOrderBy = Integer.parseInt(sOrderBy);
  }
  catch (NumberFormatException nfe) { iOrderBy = 0; }

  JDCConnection oConn = null;  
    
  try {
  
	  if (bIsAdmin) {
      sPrivate = (iPrivate==0 ? "1=1" : "b." + DB.gu_writer + "='"+id_user+"'");

	  } else {
      sPrivate = "b." + DB.gu_writer + "='"+id_user+"'";
      if (iPrivate==0) sPrivate += " OR b." + DB.bo_private + "=0";
    }

    oConn = GlobalDBBind.getConnection("oportunitylisting");

    sStatusLookUp = DBLanguages.getHTMLSelectLookUp (GlobalCacheClient, oConn, DB.k_oportunities_lookup, gu_workarea, DB.id_status, sLanguage);
    oStatusLookUp = DBLanguages.getLookUpMap(oConn, DB.k_oportunities_lookup, gu_workarea, DB.id_status, sLanguage);

    sSalesMenLookUp = GlobalCacheClient.getString("k_sales_men["+gu_workarea+"]");
    if (null==sSalesMenLookUp) {
      oSalesMen = new DBSubset(DB.k_sales_men+" m,"+DB.k_users+" u","m."+DB.gu_sales_man+",u."+DB.nm_user+",u."+DB.tx_surname1+",u."+DB.tx_surname2,
      																	"m."+DB.gu_sales_man+"=u."+DB.gu_user+" AND m."+DB.gu_workarea+"=? ORDER BY 2,3,4", 100);
      int nSalesMen = oSalesMen.load(oConn,new Object[]{gu_workarea});
      StringBuffer oMenBuff = new StringBuffer(100*(nSalesMen+1));
      for (int m=0; m<nSalesMen; m++) {
        oMenBuff.append("<OPTION VALUE=\"");
        oMenBuff.append(oSalesMen.getString(0,m));
        oMenBuff.append("\">");
        oMenBuff.append(oSalesMen.getStringNull(1,m,""));
        oMenBuff.append(" ");
        oMenBuff.append(oSalesMen.getStringNull(2,m,""));
        oMenBuff.append(" ");
        oMenBuff.append(oSalesMen.getStringNull(3,m,""));
        oMenBuff.append("</OPTION>");
      } // next
      sSalesMenLookUp = oMenBuff.toString();
      GlobalCacheClient.put("k_sales_men["+gu_workarea+"]", sSalesMenLookUp);
      oMenBuff = null;
      oSalesMen = null;
    } // fi

    int nCampaigns = oCampaigns.load(oConn, new Object[]{gu_workarea});
    for (int c=0; c<nCampaigns; c++) {
      if (!oCampaigns.isNull(2,c)) {
        if (oCampaigns.getShort(2,c)!=0)
          sCampaignsLookUp += "<OPTION VALUE=\"" + oCampaigns.getString(0,c) + "\">" + oCampaigns.getString(1,c) + "</OPTION>";
      }
    } // next
    
    if (sWhere.length()>0) {
      oOportunities = new DBSubset (DB.k_oportunities + " b", 
      				    "b." + DB.gu_oportunity + ",b." + DB.id_status+ ",b." + DB.tl_oportunity + "," + DBBind.Functions.ISNULL + "(b." + DB.tx_contact + ",b." + DB.tx_company + "),b." + DB.dt_next_action + ",b." + DB.gu_contact + ",b." + DB.gu_company + ",b." + DB.im_revenue + ",b." + DB.gu_campaign + ",b." + DB.lv_interest + ",b." + DB.id_objetive,
      				    "(b." + DB.gu_workarea + "='" + gu_workarea + "' AND (" + sPrivate + ")) " + sWhere + (iOrderBy>0 ? " ORDER BY " + sOrderBy + ",10 DESC" : " ORDER BY 10 DESC"), iMaxRows);     				 
      oOportunities.setMaxRows(iMaxRows);
      iOportunityCount = oOportunities.load (oConn);
    }
    else if (sFind.length()==0 || sField.length()==0) {
      
      oOportunities = new DBSubset (DB.k_oportunities + " b", 
      				 DB.gu_oportunity + "," + DB.id_status+ ",tl_oportunity,"+DBBind.Functions.ISNULL + "(tx_contact,tx_company),dt_next_action,gu_contact,gu_company,im_revenue,gu_campaign,lv_interest,id_objetive",
      				 DB.gu_workarea + "='" + gu_workarea + "' AND (" + sPrivate + ") " +
      				 (sStatusId.length()>0 ? " AND "+DB.id_status+"='"+sStatusId+"' " : "") +
      				 (sCampaignId.length()>0 ? " AND "+DB.gu_campaign+"='"+sCampaignId+"' " : "") +
      				 (sSalesManId.length()>0 ? " AND (EXISTS (SELECT NULL FROM "+DB.k_contacts+" c WHERE c."+DB.gu_sales_man+"='"+sSalesManId+"' AND c."+DB.gu_contact+"=b."+DB.gu_contact+") OR EXISTS (SELECT NULL FROM "+DB.k_companies+" k WHERE k."+DB.gu_sales_man+"='"+sSalesManId+"' AND k."+DB.gu_company+"=b."+DB.gu_company+")) " : "") + 
      				 (iOrderBy>0 ? " ORDER BY " + sOrderBy + ",10 DESC" : " ORDER BY 10 DESC"), iMaxRows);     				       
      oOportunities.setMaxRows(iMaxRows);      
      iOportunityCount = oOportunities.load (oConn, iSkip);
    
    }
    else {           
      if (sField.equals(DB.dt_next_action)) {
        SimpleDateFormat oDtFmt = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        oOportunities = new DBSubset (DB.k_oportunities + " b", 
      				                        DB.gu_oportunity + "," + DB.id_status+ ",tl_oportunity,"+DBBind.Functions.ISNULL + "(tx_contact,tx_company),dt_next_action,gu_contact,gu_company,im_revenue,gu_campaign,lv_interest,id_objetive",
      				                        DB.gu_workarea + "='" + gu_workarea + "' AND (" + sPrivate + ") " + " AND " +
      				                        DB.dt_next_action + " BETWEEN " + DBBind.escape(oDtFmt.parse(sFind+" 00:00:00"),"ts") + " AND " + DBBind.escape(oDtFmt.parse(sFind+" 23:59:59"),"ts") + " " +
      				                        (sStatusId.length()>0 ? " AND "+DB.id_status+"='"+sStatusId+"' " : "") +
																			(sCampaignId.length()>0 ? " AND "+DB.gu_campaign+"='"+sCampaignId+"' " : "") +
      				 												(sSalesManId.length()>0 ? " AND (EXISTS (SELECT NULL FROM "+DB.k_contacts+" c WHERE c."+DB.gu_sales_man+"='"+sSalesManId+"' AND c."+DB.gu_contact+"=b."+DB.gu_contact+") OR EXISTS (SELECT NULL FROM "+DB.k_companies+" k WHERE k."+DB.gu_sales_man+"='"+sSalesManId+"' AND k."+DB.gu_company+"=b."+DB.gu_company+")) " : "") + 
      				                        (iOrderBy>0 ? " ORDER BY " + sOrderBy + ",10 DESC" : " ORDER BY 10 DESC"), iMaxRows);
          			 
        oOportunities.setMaxRows(iMaxRows);
        iOportunityCount = oOportunities.load (oConn,iSkip);
      } else if (sField.equals(DB.gu_campaign)) {
      	int iCampaign = oCampaigns.findi(1, sFind);
      	if (iCampaign>=0) {          
          oOportunities = new DBSubset (DB.k_oportunities + " b", 
      				                          DB.gu_oportunity + "," + DB.id_status+ ",tl_oportunity,"+DBBind.Functions.ISNULL + "(tx_contact,tx_company),dt_next_action,gu_contact,gu_company,im_revenue,gu_campaign,lv_interest,id_objetive",      				 
      				                          DB.gu_workarea + "='" + gu_workarea + "' AND (" + sPrivate + ") " + " AND " +
      				                          DB.gu_campaign + "=? " +      				                          
      				                          (sStatusId.length()>0 ? " AND "+DB.id_status+"='"+sStatusId+"' " : "") +
																			  (sCampaignId.length()>0 ? " AND "+DB.gu_campaign+"='"+sCampaignId+"' " : "") +      				                          
      				 												  (sSalesManId.length()>0 ? " AND (EXISTS (SELECT NULL FROM "+DB.k_contacts+" c WHERE c."+DB.gu_sales_man+"='"+sSalesManId+"' AND c."+DB.gu_contact+"=b."+DB.gu_contact+") OR EXISTS (SELECT NULL FROM "+DB.k_companies+" k WHERE k."+DB.gu_sales_man+"='"+sSalesManId+"' AND k."+DB.gu_company+"=b."+DB.gu_company+")) " : "") + 
      				                          (iOrderBy>0 ? " ORDER BY " + sOrderBy + ",10 DESC" : " ORDER BY 10 DESC"), iMaxRows);
          oOportunities.setMaxRows(iMaxRows);
          iOportunityCount = oOportunities.load (oConn,new Object[]{oCampaigns.get(0,iCampaign)},iSkip);
        } else {
        	iOportunityCount = 0;
        }
      } else {
        oOportunities = new DBSubset (DB.k_oportunities + " b", 
      				                        DB.gu_oportunity + "," + DB.id_status+ ",tl_oportunity,"+DBBind.Functions.ISNULL + "(tx_contact,tx_company),dt_next_action,gu_contact,gu_company,im_revenue,gu_campaign,lv_interest,id_objetive",      				 
      				                        DB.gu_workarea + "='" + gu_workarea + "' AND (" + sPrivate + ") " + " AND " +
      				                        sField + " " + DBBind.Functions.ILIKE + " ? " +
      				                        (sStatusId.length()>0 ? " AND "+DB.id_status+"='"+sStatusId+"' " : "") +
																			(sCampaignId.length()>0 ? " AND "+DB.gu_campaign+"='"+sCampaignId+"' " : "") +      				                        
      				 												(sSalesManId.length()>0 ? " AND (EXISTS (SELECT NULL FROM "+DB.k_contacts+" c WHERE c."+DB.gu_sales_man+"='"+sSalesManId+"' AND c."+DB.gu_contact+"=b."+DB.gu_contact+") OR EXISTS (SELECT NULL FROM "+DB.k_companies+" k WHERE k."+DB.gu_sales_man+"='"+sSalesManId+"' AND k."+DB.gu_company+"=b."+DB.gu_company+")) " : "") + 
      				                        (iOrderBy>0 ? " ORDER BY " + sOrderBy + ",10 DESC" : " ORDER BY 10 DESC"), iMaxRows);          			 
        oOportunities.setMaxRows(iMaxRows);
        Object[] aFind = { '%' + sFind + '%' };
        iOportunityCount = oOportunities.load (oConn,aFind,iSkip);
      }
    }
    oConn.close("oportunitylisting"); 
  }
  catch (SQLException e) {  
    oOportunities = null;
    if (oConn!=null)
      if (!oConn.isClosed())
        oConn.close("oportunitylisting");
    oConn = null;
    response.sendRedirect (response.encodeRedirectUrl ("../common/errmsg.jsp?title=Error&desc=" + e.getLocalizedMessage() + "&resume=_back"));
  }
  
  if (null==oConn) return;
  
  oConn = null;  
%>

<HTML LANG="<% out.write(sLanguage); %>">
<HEAD>
  <TITLE>hipergate :: Opportunity Listing</TITLE>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="../javascript/cookies.js"></SCRIPT>  
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="../javascript/setskin.js"></SCRIPT>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="../javascript/combobox.js"></SCRIPT>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="../javascript/getparam.js"></SCRIPT>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="../javascript/getparam.js"></SCRIPT>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="../javascript/datefuncs.js"></SCRIPT>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="../javascript/dynapi/dynapi.js"></SCRIPT>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript">
    DynAPI.setLibraryPath("../javascript/dynapi/lib/");
    DynAPI.include("dynapi.api.*");

    var menuLayer,addrLayer;
    DynAPI.onLoad = function() { 
      setCombos();
      menuLayer = new DynLayer();
      menuLayer.setWidth(160);
      menuLayer.setVisible(true);
      menuLayer.setHTML(rightMenuHTML);
    }
  </SCRIPT>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="../javascript/dynapi/rightmenu.js"></SCRIPT>
  <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" DEFER="defer">
    <!--
      var jsOportunityId;
      var jsOportunityTl;
      var jsContactId;
      var jsCompanyId;

        <%          
          out.write("var jsOportunities = new Array(");
            for (int i=0; i<iOportunityCount; i++) {
              if (i>0) out.write(","); 
              out.write("\"" + oOportunities.getString(0,i) + "\"");
            }
          out.write(");\n        ");
        %>

        // ----------------------------------------------------

	function newOportunity() {	  
<% if (bIsGuest) { %>
        alert("Your credential level as Guest does not allow you to perform this action");
<% } else { %>
	  self.open ("oportunity_new.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&gu_workarea=<%=gu_workarea%>", "newoportunity", "directories=no,toolbar=no,scrollbars=yes,menubar=no,width=660,height=" + (screen.height<=600 ? "520" : "660"));	  
<% } %>
	} // newOportunity()

        // ----------------------------------------------------
        	
	function createOportunity (contact_id,company_id) {

	  self.open ("oportunity_edit.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&gu_workarea=<%=gu_workarea%>&gu_contact=" + contact_id + "&gu_company=" + company_id, "createoportunity", "directories=no,toolbar=no,menubar=no,width=660,height=660");	  
	} // createOportunity()

        // ----------------------------------------------------
	
	function deleteOportunities() {
	  var offset = 0;
	  var frm = document.forms[0];
	  var chi = frm.checkeditems;
	  	  
	  chi.value = "";
	  	  
	  frm.action = "oportunity_edit_delete.jsp";
                 
          while (frm.elements[offset].type!="checkbox") offset++;
                 
	  for (var i=0; i<jsOportunities.length; i++)	    	    
	    if (frm.elements[i+offset].checked)
              chi.value += jsOportunities[i] + ",";	              
	  
	  if (chi.value.length>0)
	    chi.value = chi.value.substr(0,chi.value.length-1);
	    
          frm.submit();
	} // deleteOportunities()
	
	
	//------------------------------------------
	      
  function findOportunity() {	 
	  var frm = document.forms[0];
	  
	  if (getCombo(frm.sel_searched)=="<%=DB.dt_next_action%>" && !isDate(frm.find.value, "d")) {
	  	alert ("Date for next action is not valid");
	  	frm.find.focus();
	  	return false;
	  }
	  window.parent.location = "oportunity_listing_f.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&skip=0&orderby=<%=sOrderBy%>&field=" + getCombo(frm.sel_searched) + "&find=" + escape(frm.find.value) + "&id_status=" + getCombo(frm.sel_status) + <% if (bCampaignsEnabled) out.write("\"&gu_campaign=\" + getCombo(frm.sel_campaign) + "); if (bIsAdmin && sSalesMenLookUp.length()>0) out.write("\"&gu_sales_man=\" + getCombo(frm.sel_salesman) + "); %> "&private=0&selected=" + getURLParam("selected") + "&subselected=" + getURLParam("subselected");	
	} // findOportunity()
	
	// ----------------------------------------------------
		
	function sortBy(fld) {
	  var frm = document.forms[0];
	  if ("<%=sField%>"=="<%=DB.dt_next_action%>" && !isDate("<%=sFind%>", "d")) {
	  	alert ("Date for next action is not valid");
	  	frm.find.focus();
	  	return false;
	  }
	  window.parent.location = "oportunity_listing_f.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&skip=0&orderby=" + fld + "&field=<%=sField%>&find=<%=sFind%>" + "&id_status=" + getCombo(frm.sel_status) + <% if (bCampaignsEnabled) out.write("\"&gu_campaign=\" + getCombo(frm.sel_campaign) + "); if (bIsAdmin && sSalesMenLookUp.length()>0) out.write("\"&gu_sales_man=\" + getCombo(frm.sel_salesman) + "); %> "&selected=" + getURLParam("selected") + "&private=<%=String.valueOf(iPrivate)%>&subselected=" + getURLParam("subselected");
	} // sortBy

	// ----------------------------------------------------

	function modifyOportunity(id,contact,company) {
	  self.open ("oportunity_edit.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&gu_oportunity=" + id +"&gu_company=" + company + "&gu_contact=" + contact, "editoportunity", "directories=no,toolbar=no,menubar=no,width=660,height=660");
	}	

      // ------------------------------------------------------

      function addPhoneCall(op,cn,cp) {
<% if (bIsGuest) { %>
        alert("Your credential level as Guest does not allow you to perform this action");
<% } else { %>
        window.open("phonecall_record.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&gu_workarea=<%=gu_workarea%>&gu_user=" + getCookie("userid") + "&gu_oportunity=" + op + "&gu_contact=" + cn + "&gu_campaign=" + cp, "recordphonecall", "directories=no,toolbar=no,menubar=no,width=660,height=660");
<% } %>        
      } // addPhoneCall

        // ----------------------------------------------------

  function modifyContact(id) {
	  self.open ("contact_edit.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&gu_contact=" + id, "editcontact", "directories=no,toolbar=no,scrollbars=yes,menubar=no,width=660,height=660");
	}	

        // ----------------------------------------------------

	function modifyCompany(id,nm) {
	  self.open ("company_edit.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&gu_company=" + id + "&n_company=" + nm + "&gu_workarea=<%=gu_workarea%>", "editcompany", "directories=no,scrollbars=yes,toolbar=no,menubar=no,width=660,height=660");
	}	

        // ----------------------------------------------------
	
	function selectAll() {	
	  var frm = document.forms[0];
          
          for (var c=0; c<frm.length; c++)                        
            if (frm.elements[c].type=="checkbox")
              frm.elements[c].click();                                    
	}	

        // ----------------------------------------------------

	function reloadPrivate(prv) {	
	  var ref;
	  var url = window.location.href;
	  var idx = url.indexOf("&private=");
	   
	  if (idx==-1)
	    window.location.href = url + "&private=" + String(prv);
	  else {
	    ref = url.substring(0,idx+9) + String(prv)
	    if (idx+10<url.length) ref += url.substring(idx+10);
	    window.location.href = ref;
	  }
	}

      // ----------------------------------------------------

      var intervalId;
      var winclone;
      
      function findCloned() {
        
        if (winclone.closed) {
          clearInterval(intervalId);
          setCombo(document.forms[0].sel_searched, "<%=DB.tl_oportunity%>");
          document.forms[0].find.value = jsOportunityTl;
          findOportunity();
        }
      } // findCloned()
      
      function clone() {        
        winclone = window.open ("../common/clone.jsp?id_domain=<%=id_domain%>&n_domain=" + escape("<%=n_domain%>") + "&datastruct=oportunity_clon&gu_instance=" + jsOportunityId +"&opcode=COPO&classid=92", "cloneoportunity", "directories=no,toolbar=no,menubar=no,width=320,height=200");                
        intervalId = setInterval ("findCloned()", 100);
      }	// clone()
	
    //-->      
  </SCRIPT>  
   <SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript">
    <!--
	function setCombos() {
		var frm = document.forms[0];
	  setCookie ("maxrows", "<%=iMaxRows%>");
	  setCombo(frm.maxresults, "<%=iMaxRows%>");
	  setCombo(frm.sel_searched, "<%=sField%>");
    setCombo(frm.sel_status, getURLParam("id_status"))
<% if (bCampaignsEnabled) { %>
    setCombo(frm.sel_campaign, getURLParam("gu_campaign"));
<% }
   if (bIsAdmin && sSalesMenLookUp.length()>0) { %>
    setCombo(frm.sel_salesman, getURLParam("gu_sales_man"));
<% } %>	    
   	} // setCombos()
    //-->    
  </SCRIPT>
    
  <STYLE TYPE="text/css">
    <!--
      .tab { font-family: sans-serif; font-size: 12px; line-height:150%; font-weight: bold; position:absolute; text-align:center; border:2px; border-color:#999999; border-style:outset; border-bottom-style:none; width:90px; margin:0px; height: 30px; cursor: hand }
  
      .panel { font-family: sans-serif; font-size: 12px; position:absolute; border: 2px; border-color:#999999; border-style:outset; width: 520px; height: 296px; left:0px; top:28px; margin:0px; padding:6px; }
    -->
  </STYLE>
 </HEAD>

<BODY  TOPMARGIN="8" MARGINHEIGHT="8" onClick="hideRightMenu()">
    <%@ include file="../common/tabmenu.jspf" %>
    <FORM name=f1 METHOD="post" onSubmit="findOportunity();return false;">     
      <TABLE><TR><TD WIDTH="<%=iTabWidth*iActive%>" CLASS="striptitle"><FONT CLASS="title1">Opportunity Listing</FONT></TD></TR></TABLE>       
      <INPUT TYPE="hidden" NAME="id_domain" VALUE="<%=id_domain%>">
      <INPUT TYPE="hidden" NAME="n_domain" VALUE="<%=n_domain%>">
      <INPUT TYPE="hidden" NAME="gu_workarea" VALUE="<%=gu_workarea%>">
      <INPUT TYPE="hidden" NAME="maxrows" VALUE="<%=String.valueOf(iMaxRows)%>">
      <INPUT TYPE="hidden" NAME="skip" VALUE="<%=String.valueOf(iSkip)%>">      
      <INPUT TYPE="hidden" NAME="checkeditems">
      <INPUT TYPE="hidden" NAME="where" VALUE="<%=sWhere%>">

      <TABLE SUMMARY="Search Options" CELLSPACING="2" CELLPADDING="2">
        <TR><TD COLSPAN="6" BACKGROUND="../images/images/loginfoot_med.gif" HEIGHT="3"></TD></TR>
        <TR>
<% if (sContactId.length()>0 || sCompanyId.length()>0) {%>
          <TD>&nbsp;&nbsp;<IMG SRC="../images/images/new16x16.gif" WIDTH="16" HEIGHT="16" BORDER="0" ALT="New Opportunity"></TD>
          <TD><A HREF="#" onclick="createOportunity('<%=sContactId%>','<%=sCompanyId%>');return false;" CLASS="linkplain">New</A></TD>        
<% } else { %>
          <TD>&nbsp;&nbsp;<IMG SRC="../images/images/new16x16.gif" WIDTH="16" HEIGHT="16" BORDER="0" ALT="New Opportunity"></TD>
          <TD ALIGN="left"><A HREF="#" onclick="newOportunity()" CLASS="linkplain">New</A></TD>
<% } %>
          <TD WIDTH="18"><IMG SRC="../images/images/papelera.gif" WIDTH="16" HEIGHT="16" BORDER="0" ALT="Delete Opportunity"></TD>
          <TD ALIGN="left">
<% if (bIsGuest) { %>
            <A HREF="#" onclick="alert('Your credential level as Guest does not allow you to perform this action')" CLASS="linkplain">Delete</A>
<% } else { %>
            <A HREF="#" onclick="deleteOportunities();return false;" CLASS="linkplain">Delete</A>
<% } %>
          </TD>
          <TD></TD>
        </TR>
			  <TR>
          <TD></TD>
	        <TD><SELECT NAME="sel_searched" CLASS="combomini" onchange="if (this.options[this.selectedIndex].value=='<%=DB.dt_next_action%>' && document.forms[0].find.value.length==0) document.forms[0].find.value=dateToString(new Date(),'d')"><OPTION VALUE="<%=DB.tl_oportunity%>">Title<OPTION VALUE="<%=DB.tx_contact%>">Contact<OPTION VALUE="<%=DB.tx_company%>">Company<OPTION VALUE="<%=DB.dt_next_action%>">Next Action</SELECT></TD>
	        <TD COLSPAN="2"><INPUT TYPE="text" NAME="find" MAXLENGTH="50" VALUE="<%=sFind%>"></TD>
          <TD ALIGN="right"><FONT CLASS="textplain">Status&nbsp;</FONT></TD>
          <TD><SELECT NAME="sel_status" CLASS="combomini"><OPTION VALUE=""></OPTION><%=sStatusLookUp%></SELECT></TD>
        </TR>
<% if (bCampaignsEnabled) { %>
        <TR>
          <TD></TD>
          <TD><FONT CLASS="textplain">Campaign</FONT></TD>
          <TD COLSPAN="4"><SELECT NAME="sel_campaign" CLASS="combomini"><OPTION VALUE=""></OPTION><%=sCampaignsLookUp%></SELECT>
        </TR>
<% } %>
<% if (bIsAdmin && sSalesMenLookUp.length()>0) { %>
        <TR>
          <TD></TD>
          <TD><FONT CLASS="textplain">[~Vendedor~]</FONT></TD>
          <TD COLSPAN="4"><SELECT NAME="sel_salesman" CLASS="combomini"><OPTION VALUE=""></OPTION><%=sSalesMenLookUp%></SELECT>
        </TR>
<% } %>
        <TR>
          <TD>&nbsp;&nbsp;<IMG SRC="../images/images/find16.gif" HEIGHT="16" BORDER="0" ALT="Search"></TD>
	        <TD><A HREF="#" onclick="findOportunity();return false;" CLASS="linkplain" TITLE="Find Opportunity">Search</A></TD>
          <TD VALIGN="bottom"><IMG SRC="../images/images/findundo16.gif" HEIGHT="16" BORDER="0" ALT="Discard Find Filter"></TD>
          <TD><A HREF="#" onclick="document.forms[0].sel_status.selectedIndex=0;document.forms[0].sel_searched.selectedIndex=0;document.forms[0].find.value='';<% if (bIsAdmin && sSalesMenLookUp.length()>0) { %>document.forms[0].sel_salesman.selectedIndex=0;<% } %>findOportunity();return false;" CLASS="linkplain" TITLE="Discard Find Filter">Discard</A></TD>
          <TD ALIGN="right" CLASS="textplain">Show&nbsp;</TD>
          <TD><SELECT CLASS="combomini" NAME="maxresults" onchange="setCookie('maxrows',getCombo(document.forms[0].maxresults));"><OPTION VALUE="10">10<OPTION VALUE="20">20<OPTION VALUE="50">50<OPTION VALUE="100">100<OPTION VALUE="200">200<OPTION VALUE="500">500</SELECT><FONT CLASS="textplain">&nbsp;&nbsp;&nbsp;results&nbsp;</FONT></TD>        
        </TR>
        <TR><TD COLSPAN="6" BACKGROUND="../images/images/loginfoot_med.gif" HEIGHT="3"></TD></TR>
        <TR>
          <TD ALIGN="right"><INPUT TYPE="radio" NAME="private" <% if (iPrivate!=0) out.write("CHECKED"); else out.write("onClick=\"reloadPrivate(1);\""); %>></TD>
          <TD COLSPAN="3" CLASS="textplain">View private opportunities only</TD>          
          <TD ALIGN="left" COLSPAN="2" CLASS="textplain"><INPUT TYPE="radio" NAME="private" <% if (iPrivate==0) out.write("CHECKED"); else out.write("onClick=\"reloadPrivate(0);\""); %>>&nbsp;<% if (bIsAdmin) out.write("[~Ver todas~]"); else out.write("View Public & Private Opportunities"); %></TD>
        </TR>
        <TR><TD COLSPAN="6" BACKGROUND="../images/images/loginfoot_med.gif" HEIGHT="3"></TD></TR>
          <TD>&nbsp;&nbsp;<IMG SRC="../images/images/addrbook/telephone16.gif" WIDTH="16" HEIGHT="16" BORDER="0" ALT="[~Llamada~]"></TD>
          <TD COLSPAN="5"><A HREF="#" oncontextmenu="return false;" onclick="if (document.forms[0].sel_campaign.selectedIndex<=0) { alert('[~Debe seleccionar previamente la campaña sobre la cual generar la llamada~]'); document.forms[0].sel_campaign.focus(); } else { addPhoneCall('','',getCombo(document.forms[0].sel_campaign)); } return false;" CLASS="linkplain">[~Generar llamada para un contacto elegido automáticamente~]</A></TD>
			  </TR>
        <TR><TD COLSPAN="6" BACKGROUND="../images/images/loginfoot_med.gif" HEIGHT="3"></TD></TR>
      </TABLE>
      <%
   
     if (iSkip>0)
       out.write("            <A HREF=\"oportunity_listing.jsp?id_domain=" + id_domain + "&n_domain=" + n_domain + "&skip=" + String.valueOf(iSkip-iMaxRows) + "&orderby=" + sOrderBy + "&field=" + sField + "&find=" + sFind + "&selected=" + request.getParameter("selected") + "&subselected=" + request.getParameter("subselected") + "\" CLASS=\"linkplain\">&lt;&lt;&nbsp;Previous" + "</A>&nbsp;&nbsp;&nbsp;");
         
     if (iOportunityCount>0) {
       if (!oOportunities.eof())
         out.write("            <A HREF=\"oportunity_listing.jsp?id_domain=" + id_domain + "&n_domain=" + n_domain + "&skip=" + String.valueOf(iSkip+iMaxRows) + "&orderby=" + sOrderBy + "&field=" + sField + "&find=" + sFind + "&selected=" + request.getParameter("selected") + "&subselected=" + request.getParameter("subselected") + "\" CLASS=\"linkplain\">Next&nbsp;&gt;&gt;</A>");
     }

    %>
    
      <TABLE SUMMARY="Leads List" CELLSPACING="1" CELLPADDING="0">
        <TR>
        	<TD CLASS="tableheader" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif"></TD>        	
          <TD CLASS="tableheader" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif">&nbsp;<A HREF="javascript:sortBy(2);" oncontextmenu="return false;"><IMG SRC="../skins/<%=sSkin + (iOrderBy==2 ? "/sortedfld.gif" : "/sortablefld.gif")%>" WIDTH="14" HEIGHT="10" BORDER="0" ALT="Order by this field"></A>&nbsp;<B>Status</B>&nbsp;</TD>
          <TD CLASS="tableheader" WIDTH="320" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif">&nbsp;<A HREF="javascript:sortBy(3);" oncontextmenu="return false;"><IMG SRC="../skins/<%=sSkin + (iOrderBy==3 ? "/sortedfld.gif" : "/sortablefld.gif")%>" WIDTH="14" HEIGHT="10" BORDER="0" ALT="Order by this field"></A>&nbsp;<B>Title</B></TD>
          <TD CLASS="tableheader" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif">&nbsp;<B>Campaign</B></TD>
          <TD CLASS="tableheader" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif">&nbsp;<A HREF="javascript:sortBy(4);" oncontextmenu="return false;"><IMG SRC="../skins/<%=sSkin + (iOrderBy==5 ? "/sortedfld.gif" : "/sortablefld.gif")%>" WIDTH="14" HEIGHT="10" BORDER="0" ALT="Order by this field"></A>&nbsp;&nbsp;<B>Client</B></TD>
          <TD CLASS="tableheader" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif">&nbsp;<A HREF="javascript:sortBy(8);" oncontextmenu="return false;"><IMG SRC="../skins/<%=sSkin + (iOrderBy==8 ? "/sortedfld.gif" : "/sortablefld.gif")%>" WIDTH="14" HEIGHT="10" BORDER="0" ALT="Order by this field"></A>&nbsp;&nbsp;<B>Amount</B>&nbsp;</TD>
          <TD CLASS="tableheader" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif">&nbsp;<A HREF="javascript:sortBy(9);" oncontextmenu="return false;"><IMG SRC="../skins/<%=sSkin + (iOrderBy==9 ? "/sortedfld.gif" : "/sortablefld.gif")%>" WIDTH="14" HEIGHT="10" BORDER="0" ALT="Order by this field"></A>&nbsp;<B>Next Action</B>&nbsp;</TD>
          <TD CLASS="tableheader" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif">&nbsp;<A HREF="javascript:sortBy(11);" oncontextmenu="return false;"><IMG SRC="../skins/<%=sSkin + (iOrderBy==11 ? "/sortedfld.gif" : "/sortablefld.gif")%>" WIDTH="14" HEIGHT="10" BORDER="0" ALT="Order by this field"></A>&nbsp;<B>[~Objetivo~]</B>&nbsp;</TD>
          <TD CLASS="tableheader" WIDTH="20" BACKGROUND="../skins/<%=sSkin%>/tablehead.gif" ALIGN="center"><A HREF="#" onclick="selectAll()" TITLE="Seleccionar todos"><IMG SRC="../images/images/selall16.gif" BORDER="0" ALT="Select all"></A></TD>
        </TR>
<%
	  String sOpId, sOpSt, sOpTl, sOpCl, sOpDt, sOpCn, sOpCm, sOpRv, sOpCp, sOpLv, sOpOb;
	  Object oOpDt, oOpRv;
	  
	  for (int i=0; i<iOportunityCount; i++) {
            sOpId = oOportunities.getString(0,i);
            sOpSt = (String) oStatusLookUp.get(oOportunities.getStringNull(1,i,""));
            if (null==sOpSt) sOpSt = oOportunities.getStringNull(1,i,"");
            sOpTl = oOportunities.getStringNull(2,i,"* N/A *");
            sOpCl = oOportunities.getString(3,i);            
            oOpDt = oOportunities.get(4,i);
            if (null!=oOpDt)
              sOpDt = oSimpleDate.format((Date)oOpDt);
            else 
              sOpDt = "";
            sOpCn = oOportunities.getStringNull(5,i,"");
            sOpCm = oOportunities.getStringNull(6,i,"");  
            oOpRv = oOportunities.get(7,i);  
            if (null!=oOpRv)
              sOpRv = oOpRv.toString();
            else 
              sOpRv = "";
            if (oOportunities.isNull(8,i))
              sOpCp = "";
            else
            	sOpCp = oCampaigns.getString(1, oCampaigns.find(0, oOportunities.get(8,i)));
            if (oOportunities.isNull(9,i))
              sOpLv = "0";
            else
            	sOpLv = String.valueOf(oOportunities.getShort(9,i));
            sOpOb = oOportunities.getStringNull(10,i,"");
%>
	<TR HEIGHT="14">
		<TD CLASS="striplv<%=sOpLv%>">&nbsp;<%
			if (oOportunities.getStringNull(1,i,"").equals("ENCURSO")) { %>
			  <IMG SRC="../images/images/addrbook/callongoing.gif" WIDTH="22" HEIGHT="14" BORDER="0" ALT="[~Ongoing Call~]"></A>
<%	  } else if (sOpCn.length()>0) { %>
			  <A HREF="#" onclick="addPhoneCall('<%=sOpId%>', '<%=sOpCn%>','')" TITLE="Call"><IMG SRC="../images/images/addrbook/telephone16.gif" WIDTH="16" HEIGHT="16" BORDER="0" ALT="Call"></A>
<%    } %>
    </TD>
	  <TD CLASS="striplv<%=sOpLv%>">&nbsp;<%=sOpSt%>&nbsp;</TD>
	  <TD CLASS="striplv<%=sOpLv%>">&nbsp;<A HREF="#" oncontextmenu="jsOportunityId='<%=sOpId%>'; jsOportunityTl='<%=sOpTl%>'; jsContactId='<%=sOpCn%>'; jsCompanyId='<%=sOpCm%>'; return showRightMenu(event);" onmouseover="window.status='Editar Oportunidad'; return true;" onmouseout="window.status='';" onclick="modifyOportunity('<%=sOpId%>','<%=sOpCn%>','<%=sOpCm%>')" TITLE="Click Right Mouse Button for Context Menu"><%=sOpTl%></A></TD>
	  <TD CLASS="striplv<%=sOpLv%>">&nbsp;<%=sOpCp%></TD>
	  <TD CLASS="striplv<%=sOpLv%>">&nbsp;<A HREF="#" CLASS="linkplain" oncontextmenu="return false;" onclick="<%=(sOpCn.length()>0 ? "modifyContact('"+sOpCn+"')" : "modifyCompany('"+sOpCm+"','"+Gadgets.URLEncode(sOpCl)+"'))")%>"><%=sOpCl%></A></TD>
	  <TD CLASS="striplv<%=sOpLv%>" ALIGN="right">&nbsp;<%=sOpRv%></TD>
	  <TD CLASS="striplv<%=sOpLv%>" ALIGN="right">&nbsp;<%=sOpDt%>&nbsp;</TD>
	  <TD CLASS="striplv<%=sOpLv%>" ALIGN="center">&nbsp;<%=sOpOb%>&nbsp;</TD>
	  <TD CLASS="striplv<%=sOpLv%>" WIDTH="20" ><INPUT TYPE="checkbox" VALUE="<%=sOpId%>"></TD>
	</TR>
<% } %>
      </TABLE>
    </FORM>
    <SCRIPT language="JavaScript" type="text/javascript">
      addMenuOption("Open","modifyOportunity(jsOportunityId, jsContactId, jsCompanyId)",1);
      addMenuSeparator();
      addMenuOption("Duplicate","clone()",0);
      addMenuSeparator();
      addMenuOption("Call","addPhoneCall(jsOportunityId, jsContactId, '')",0);
    </SCRIPT>
  </BODY>
</HTML>

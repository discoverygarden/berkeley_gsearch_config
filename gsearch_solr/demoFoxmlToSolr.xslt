﻿<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id: demoFoxmlToLucene.xslt 5734 2006-11-28 11:20:15Z gertsp $ -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
  xmlns:islandora-exts="xalan://ca.upei.roblib.DataStreamForXSLT"
    		exclude-result-prefixes="exts"
  xmlns:zs="http://www.loc.gov/zing/srw/"
  xmlns:foxml="info:fedora/fedora-system:def/foxml#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
  xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
  xmlns:rel="info:fedora/fedora-system:def/relations-external#"
  xmlns:dwc="http://rs.tdwg.org/dwc/xsd/simpledarwincore/"
  xmlns:fedora-model="info:fedora/fedora-system:def/model#"
  xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
  xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/"
  xmlns:eaccpf="urn:isbn:1-931666-33-4"
  xmlns:res="http://www.w3.org/2001/sw/DataAccess/rf1/result"
  xmlns:xalan="http://xml.apache.org/xalan"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xmlns:ext="http://exslt.org/common"
  xmlns:java="http://xml.apache.org/xalan/java">
  <xsl:import href="/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/config/index/gsearch_solr/fxsl-1.2/strSplit-to-Words.xsl"/>
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

  <xsl:param name="REPOSITORYNAME" select="repositoryName"/>
  <xsl:param name="FEDORASOAP" select="repositoryName"/>
  <xsl:param name="FEDORAUSER" select="repositoryName"/>
  <xsl:param name="FEDORAPASS" select="repositoryName"/>
  <xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
  <xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>

  <!-- Test of adding explicit parameters to indexing -->
  <xsl:param name="EXPLICITPARAM1" select="defaultvalue1"/>
  <xsl:param name="EXPLICITPARAM2" select="defaultvalue2"/>
<!--
	 This xslt stylesheet generates the IndexDocument consisting of IndexFields
     from a FOXML record. The IndexFields are:
       - from the root element = PID
       - from foxml:property   = type, state, contentModel, ...
       - from oai_dc:dc        = title, creator, ...
     The IndexDocument element gets a PID attribute, which is mandatory,
     while the PID IndexField is optional.
     Options for tailoring:
       - IndexField types, see Lucene javadoc for Field.Store, Field.Index, Field.TermVector
       - IndexField boosts, see Lucene documentation for explanation
       - IndexDocument boosts, see Lucene documentation for explanation
       - generation of IndexFields from other XML metadata streams than DC
         - e.g. as for uvalibdesc included above and called below, the XML is inline
         - for not inline XML, the datastream may be fetched with the document() function,
           see the example below (however, none of the demo objects can test this)
       - generation of IndexFields from other datastream types than XML
         - from datastream by ID, text fetched, if mimetype can be handled
         - from datastream by sequence of mimetypes,
           text fetched from the first mimetype that can be handled,
           default sequence given in properties.
-->

  <xsl:template match="/">
    <xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
    <add>
      <!-- The following allows only active FedoraObjects to be indexed. -->
      <xsl:if test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state' and @VALUE='Active']">
        <xsl:if test="not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP' or @ID='DS-COMPOSITE-MODEL'])">
          <!-- How different name spaces might be indexed differently...
          <xsl:choose>
            <xsl:when test="starts-with($PID,'atm')">
              <xsl:call-template name="fjm-atm">
                <xsl:with-param name="pid" select="$PID"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
            -->
              <xsl:apply-templates select="/foxml:digitalObject" mode="activeFedoraObject">
                <xsl:with-param name="PID" select="$PID"/>
              </xsl:apply-templates>
            <!--
            </xsl:otherwise>
          </xsl:choose>
          -->
        </xsl:if>
      </xsl:if>
    </add>
  </xsl:template>

  <xsl:template match="/foxml:digitalObject" mode="activeFedoraObject">
    <xsl:param name="PID"/>

    <doc>
      <field name="PID" boost="2.5">
        <xsl:value-of select="$PID"/>
      </field>

      <xsl:apply-templates select="foxml:objectProperties/foxml:property"/>

      <!-- index DC -->
      <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/oai_dc:dc/*">
        <xsl:with-param name="prefix">dc.</xsl:with-param>
        <xsl:with-param name="suffix"></xsl:with-param>
      </xsl:apply-templates>

      <xsl:for-each select="foxml:datastream[@ID='RIGHTSMETADATA']/foxml:datastreamVersion[last()]/foxml:xmlContent//access/human/person">
        <field>
          <xsl:attribute name="name">access.person</xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:for-each>
      <xsl:for-each select="foxml:datastream[@ID='RIGHTSMETADATA']/foxml:datastreamVersion[last()]/foxml:xmlContent//access/human/group">
        <field>
          <xsl:attribute name="name">access.group</xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:for-each>
      <xsl:for-each select="foxml:datastream[@ID='TAGS']/foxml:datastreamVersion[last()]/foxml:xmlContent//tag">
            <!--<xsl:for-each select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent//tag">-->
        <field>
          <xsl:attribute name="name">tag</xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
        <field>
          <xsl:attribute name="name">tagUser</xsl:attribute>
          <xsl:value-of select="@creator"/>
        </field>
      </xsl:for-each>

      <!-- Index the Rels-ext (using match="rdf:RDF") -->
      <xsl:apply-templates select="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF">
        <xsl:with-param name="prefix">rels_</xsl:with-param>
        <xsl:with-param name="suffix">_ms</xsl:with-param>
      </xsl:apply-templates>

        <!--*************************************************************full text************************************************************************************-->
        <!--  Filter added to ensure OCR streams for ilives books are NOT included -->
      <xsl:for-each select="foxml:datastream[@ID='OCR']/foxml:datastreamVersion[last()]">
        <xsl:if test="not(starts-with($PID,'ilives'))">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat('OCR.', 'OCR')"/>
            </xsl:attribute>
            <xsl:value-of select="islandora-exts:getDatastreamTextRaw($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
          </field>
        </xsl:if>
      </xsl:for-each>
        <!--  Filter added to ensure OCR streams for ilives books are NOT included -->
      <xsl:for-each select="foxml:datastream[@ID='OBJ']/foxml:datastreamVersion[last()]">
        <xsl:if test="starts-with($PID,'ir')">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat('dsm.', 'text')"/>
            </xsl:attribute>
            <xsl:value-of select="islandora-exts:getDatastreamText($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
          </field>
        </xsl:if>
      </xsl:for-each>
        <!--***********************************************************end full text********************************************************************************-->
      <xsl:variable name="pageCModel">
        <xsl:text>info:fedora/ilives:pageCModel</xsl:text>
      </xsl:variable>
      <xsl:variable name="thisCModel">
        <xsl:value-of select="//fedora-model:hasModel/@rdf:resource"/>
      </xsl:variable>
        <!-- why was this being output here?:
        <xsl:value-of select="$thisCModel"/>-->

        <!--********************************************Darwin Core**********************************************************************-->
      <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/dwc:SimpleDarwinRecordSet/dwc:SimpleDarwinRecord/*[normalize-space(text())]">
        <xsl:with-param name="prefix">dwc.</xsl:with-param>
        <xsl:with-param name="suffix"></xsl:with-param>
      </xsl:apply-templates>
        <!--***************************************** END Darwin Core ******************************************-->

        <!--************************************ BLAST ******************************************-->
        <!-- Blast -->
        <!--
      <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='BLAST']/foxml:datastreamVersion[last()]/foxml:xmlContent//Hit/Hit_hsps/Hsp/*[normalize-space(text())]">
        <xsl:with-param name="prefix">blast.</xsl:with-param>
        <xsl:with-param name="suffix"></xsl:with-param>
      </xsl:apply-templates>
      -->
        <!--********************************** End BLAST ******************************************-->

        <!-- Names and Roles -->
      <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="default"/>

      <!-- store an escaped copy of MODS... -->
      <xsl:if test="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods">
        <field name="mods_fullxml_store">
          <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="escape"/>
        </field>
      </xsl:if>

      <xsl:apply-templates select="foxml:datastream[@ID='EAC-CPF']/foxml:datastreamVersion[last()]/foxml:xmlContent//eaccpf:eac-cpf">
        <xsl:with-param name="pid" select="$PID"/>
      </xsl:apply-templates>
      
      <xsl:apply-templates select="foxml:datastream[@ID='EAC-CPF']/foxml:datastreamVersion[last()]/foxml:xmlContent//eaccpf:eac-cpf" mode="CoH"/>
      
      <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="CoH">
        <xsl:with-param name="prefix">coh_search_</xsl:with-param>
        <xsl:with-param name="suffix"></xsl:with-param>
      </xsl:apply-templates>
      
      <xsl:apply-templates select="foxml:datastream[@ID='SPMS']/foxml:datastreamVersion[last()]/foxml:xmlContent//spms" mode="default"/>

      <!--
      <xsl:apply-templates mode="fjm" select="foxml:datastream[@ID='EAC-CPF']/foxml:datastreamVersion[last()]/foxml:xmlContent//eaccpf:eac-cpf">
        <xsl:with-param name="pid" select="$PID"/>
        <xsl:with-param name="suffix">_s</xsl:with-param>
      </xsl:apply-templates>
      -->

      <xsl:for-each select="foxml:datastream[@ID][foxml:datastreamVersion[last()]]">
          <xsl:choose>
            <!-- Don't bother showing some... -->
            <xsl:when test="@ID='AUDIT'"></xsl:when>
            <xsl:when test="@ID='DC'"></xsl:when>
            <xsl:when test="@ID='ENDNOTE'"></xsl:when>
            <xsl:when test="@ID='MODS'"></xsl:when>
            <xsl:when test="@ID='RIS'"></xsl:when>
            <xsl:when test="@ID='SWF'"></xsl:when>
            <xsl:otherwise>
              <field name="fedora_datastreams_ms">
                <xsl:value-of select="@ID"/>
              </field>
            </xsl:otherwise>
          </xsl:choose>
      </xsl:for-each>
    </doc>
  </xsl:template>

  <xsl:template match="foxml:property">
    <xsl:param name="prefix">fgs_</xsl:param>
    <xsl:param name="suffix">_s</xsl:param>
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, substring-after(@NAME,'#'), $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="@VALUE"/>
    </field>
  </xsl:template>
  
  <!-- some SPMS -->
  <xsl:template match="spms" name="index_spms" mode="default">
    <xsl:param name="prefix">spms_</xsl:param>
    <xsl:param name="suffix">_ms</xsl:param>
    <xsl:param name="suffix_ng">_ng</xsl:param>
    
    <!-- Read and parse divisions -->
    <xsl:for-each select="ALL_DIVISIONS|all_divisions">
      <xsl:variable name="vwordNodes">
        <xsl:call-template name="str-split-to-words">
          <xsl:with-param name="pStr" select="text()"/>
          <xsl:with-param name="pDelimiters" select="','"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="ext:node-set($vwordNodes)/*">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'divisions', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:for-each>
    </xsl:for-each>
   
    <!-- REPORT_NUMBER -->
    <xsl:for-each select="REPORT_NUMBER|report_number">
      <xsl:variable name="vwordNodes">
        <xsl:call-template name="str-split-to-words">
          <xsl:with-param name="pStr" select="text()"/>
          <xsl:with-param name="pDelimiters" select="','"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="ext:node-set($vwordNodes)/*">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'report_number', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:for-each>
    </xsl:for-each>
 
    <!-- Groups -->
    <xsl:for-each select="LBNL_GROUP|lbnl_group">
      <xsl:if test="text()">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'group', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'group', $suffix_ng)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:if>
    </xsl:for-each>
    
    <!-- Categories -->
    <xsl:for-each select="ALL_CATEGORIES|all_categories">
      <xsl:variable name="vwordNodes">
        <xsl:call-template name="str-split-to-words">
          <xsl:with-param name="pStr" select="text()"/>
          <xsl:with-param name="pDelimiters" select="','"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="ext:node-set($vwordNodes)/*">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'categories', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:for-each>
    </xsl:for-each>
    
    <!-- Keywords -->
    <xsl:for-each select="KEYWORDS|keywords">
      <xsl:variable name="vwordNodes">
        <xsl:call-template name="str-split-to-words">
          <xsl:with-param name="pStr" select="text()"/>
          <xsl:with-param name="pDelimiters" select="','"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="ext:node-set($vwordNodes)/*">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'keywords', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:for-each>
    </xsl:for-each>

    <!-- Tag -->
    <xsl:for-each select="TAG|tag">
      <xsl:if test="text()">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'tag', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'tag', $suffix_ng)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:if>
    </xsl:for-each>
 
    <!-- Project -->
    <xsl:for-each select="PROJECT|project">
      <xsl:if test="text()">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'project', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'project', $suffix_ng)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:if>
    </xsl:for-each>

    <!-- Facility -->
    <xsl:for-each select="FACILITY|facility">
      <xsl:if test="text()">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'facility', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'facility', $suffix_ng)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:if>
    </xsl:for-each>

    <!-- PROJECT_ID -->
    <xsl:for-each select="PROJECT_ID|project_id">
      <xsl:if test="text()">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'project_id', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'project_id', $suffix_ng)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>
      </xsl:if>
    </xsl:for-each>
 
    <!-- Embargo -->
    <xsl:for-each select="EMBARGO|embargo">
      <xsl:if test="text()">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'embargo', $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(text())"/>
        </field>        
      </xsl:if>
    </xsl:for-each>
    
  </xsl:template>

  <!-- Basic MODS -->
  <xsl:template match="mods:mods" name="index_mods" mode="default">
    <xsl:param name="prefix">mods_</xsl:param>
    <xsl:param name="suffix">_ms</xsl:param>

    <!-- Index stuff from the auth-module. -->
    <xsl:for-each select=".//*[@authorityURI='info:fedora'][@valueURI]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'related_object', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@valueURI"/>
      </field>
    </xsl:for-each>

    <!--************************************ MODS subset for Bibliographies ******************************************-->

    <!-- Main Title, with non-sorting prefixes -->
    <!-- ...specifically, this avoids catching relatedItem titles -->
    <xsl:for-each select="(./mods:titleInfo/mods:title[normalize-space(text())])[1]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:if test="../mods:nonSort">
          <xsl:value-of select="../mods:nonSort/text()"/>
          <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:value-of select="text()"/>
      </field>
      <!-- bit of a hack so it can be sorted on... -->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_s')"/>
        </xsl:attribute>
        <xsl:if test="../mods:nonSort">
          <xsl:value-of select="../mods:nonSort/text()"/>
          <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Sub-title -->
    <xsl:for-each select="./mods:titleInfo/mods:subTitle[normalize-space(text())][1]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_s')"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Abstract -->
    <xsl:for-each select=".//mods:abstract[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Genre (a.k.a. specific doctype) -->
    <xsl:for-each select=".//mods:genre[normalize-space(text())]">
      <xsl:variable name="authority">
        <xsl:choose>
          <xsl:when test="@authority">
            <xsl:value-of select="concat('_', @authority)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>_local_authority</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $authority, $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!--  Resource Type (a.k.a. broad doctype) -->
    <xsl:for-each select="./mods:typeOfResource[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'resource_type', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- DOI, ISSN, ISBN, and any other typed IDs -->
    <xsl:for-each select="./mods:identifier[@type][normalize-space(text())]">
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, @type, $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="text()"/>
    </field>
    </xsl:for-each>

      <!-- Names and Roles -->
    <xsl:for-each select=".//mods:roleTerm[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'name_', text(), $suffix)"/>
        </xsl:attribute>
        <xsl:for-each select="../../mods:namePart[@type='given']">
          <xsl:value-of select="text()"/>
          <xsl:if test="string-length(text())=1">
            <xsl:text>.</xsl:text>
          </xsl:if>
          <xsl:text> </xsl:text>
        </xsl:for-each>
        <xsl:for-each select="../../mods:namePart[not(@type='given')]">
          <xsl:value-of select="text()"/>
          <xsl:if test="position()!=last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </field>
      <xsl:if test="../../mods:namePart[@type='given'] != '' or ../../mods:namePart[not(@type='given')] != ''">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'rname_', text(), $suffix)"/>
        </xsl:attribute>
        <xsl:for-each select="../../mods:namePart[not(@type='given')]">
          <xsl:if test="text() != ''">
            <xsl:value-of select="text()"/>
          </xsl:if>
        </xsl:for-each>
        <xsl:for-each select="../../mods:namePart[@type='given']">
          <xsl:if test="position()=1 and ../mods:namePart[not(@type='given')] != ''">
            <xsl:text>, </xsl:text>
          </xsl:if>
          <xsl:if test="text() != ''">
            <xsl:value-of select="text()"/>
          </xsl:if>
        </xsl:for-each>
      </field>
    </xsl:if>
    </xsl:for-each>
      <!-- Names with no Role -->
    <xsl:for-each select=".//mods:name[not(child::role)]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'name_generic', $suffix)"/>
        </xsl:attribute>
        <xsl:for-each select="./mods:namePart[@type='given']">
          <xsl:value-of select="text()"/>
          <xsl:if test="string-length(text())=1">
            <xsl:text>.</xsl:text>
          </xsl:if>
          <xsl:text> </xsl:text>
        </xsl:for-each>
        <xsl:for-each select="./mods:namePart[not(@type='given')]">
          <xsl:value-of select="text()"/>
          <xsl:if test="position()!=last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </field>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'rname_generic', $suffix)"/>
        </xsl:attribute>
        <xsl:for-each select="./mods:namePart[not(@type='given')]">
          <xsl:value-of select="text()"/>
          <xsl:if test="@type='given'">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
        <xsl:for-each select="./mods:namePart[@type='given']">
          <xsl:if test="position()=1">
            <xsl:text>, </xsl:text>
          </xsl:if>
          <xsl:value-of select="text()"/>
          <xsl:if test="string-length(text())=1">
            <xsl:text>.</xsl:text>
          </xsl:if>
          <xsl:if test="position()!=last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </field>
    </xsl:for-each>

      <!-- Notes -->
    <xsl:for-each select=".//mods:note[normalize-space(text())]">
          <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Subjects / Keywords -->
    <xsl:for-each select=".//mods:subject/*[normalize-space(text())]">
              <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'subject', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Country -->
      <xsl:for-each select=".//mods:country[normalize-space(text())]">
        <!--don't bother with empty space-->
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:for-each>

      <xsl:for-each select=".//mods:province[normalize-space(text())]">
        <!--don't bother with empty space-->
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:for-each>
      <xsl:for-each select=".//mods:county[normalize-space(text())]">
          <!--don't bother with empty space-->
          <field>
              <xsl:attribute name="name">
                  <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
              </xsl:attribute>
              <xsl:value-of select="text()"/>
          </field>
      </xsl:for-each>
      <xsl:for-each select=".//mods:region[normalize-space(text())]">
          <!--don't bother with empty space-->
          <field>
              <xsl:attribute name="name">
                  <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
              </xsl:attribute>
              <xsl:value-of select="text()"/>
          </field>
      </xsl:for-each>
      <xsl:for-each select=".//mods:city[normalize-space(text())]">
        <!--don't bother with empty space-->
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:for-each>
      <xsl:for-each select=".//mods:citySection[normalize-space(text())]">
        <!--don't bother with empty space-->
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:for-each>

      <!-- Host Name (i.e. journal/newspaper name) -->
    <xsl:for-each select=".//mods:relatedItem[@type='host']/mods:titleInfo/mods:title[normalize-space(text())]">
          <!--don't bother with empty space-->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'host_title', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Series Name (this means, e.g. a lecture series and is rarely used) -->
    <xsl:for-each select=".//mods:relatedItem[@type='series']/mods:titleInfo/mods:title[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'series_title', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Volume (e.g. journal vol) -->
    <xsl:for-each select="./mods:part/mods:detail[@type='volume']/*[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'volume', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Issue (e.g. journal vol) -->
    <xsl:for-each select="./mods:part/mods:detail[@type='issue']/*[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'issue', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <xsl:for-each select="./mods:originInfo/mods:dateIssued">
      <xsl:variable name="textValue">
        <xsl:call-template name="get_ISO8601_date">
          <xsl:with-param name="date" select="normalize-space(text())"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="$textValue">
        <xsl:if test="./@qualifier='approximate'">
          <field>
            <xsl:attribute name="name"><xsl:value-of select="concat($prefix, 'date_issued_approximate', '_dt')"/></xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
        <xsl:if test="./@qualifier='questionable'">
          <field>
            <xsl:attribute name="name"><xsl:value-of select="concat($prefix, 'date_issued_questionable', '_dt')"/></xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:if>
    </xsl:for-each>

    <xsl:if test="./mods:originInfo/mods:dateIssued">
      <xsl:variable name="textValue">
        <xsl:call-template name="get_ISO8601_date">
          <xsl:with-param name="date" select="normalize-space(./mods:originInfo/mods:dateIssued[position()=1])"/>
        </xsl:call-template>
      </xsl:variable>
      <field>
        <xsl:attribute name="name"><xsl:value-of select="concat($prefix, 'date_issued', '_dt')"/></xsl:attribute>
        <xsl:value-of select="$textValue"/>
      </field>
    </xsl:if>


      <!-- Subject Names - not necessary for our MODS citations -->
    <xsl:for-each select=".//mods:subject/mods:name/mods:namePart/*[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'subject', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Physical Description - not necessary for our MODS citations -->
    <xsl:for-each select=".//mods:physicalDescription/*[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Place of publication -->
    <xsl:for-each select=".//mods:originInfo/mods:place/mods:placeTerm[@type='text'][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'place_of_publication', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Publisher's Name -->
    <xsl:for-each select=".//mods:originInfo/mods:publisher[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Edition (Book) -->
    <xsl:for-each select=".//mods:originInfo/mods:edition[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Date Issued (i.e. Journal Pub Date) -->
    <xsl:for-each select=".//mods:originInfo/mods:dateIssued[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
      <xsl:if test="position() = 1"><!-- use the first for a sortable field -->
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), '_s')"/>
          </xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
      </xsl:if>
    </xsl:for-each>

      <!-- Copyright Date (is an okay substitute for Issued Date in many circumstances) -->
    <xsl:for-each select=".//mods:originInfo/mods:copyrightDate[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Issuance (i.e. ongoing, monograph, etc. ) -->
    <xsl:for-each select=".//mods:originInfo/mods:issuance[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

      <!-- Languague Term -->
    <xsl:for-each select=".//mods:language/mods:languageTerm[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
  </xsl:template>
  <!-- End Basic MODS -->
  
  <!-- *** COH - EAC-CPF ERP data *** -->
  <xsl:template match="eaccpf:eac-cpf" mode="CoH" name="index_eaccpf_for_CoH" >
    <!-- defaults -->
    <xsl:param name="prefix">coh_erp_</xsl:param>
    <xsl:param name="suffix"></xsl:param>
    <xsl:for-each select=".//eaccpf:cpfDescription/eaccpf:identity[eaccpf:entityType = 'corporateBody' and eaccpf:nameEntry/eaccpf:part[@localType='project']]/eaccpf:entityId">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'project_id', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select=".//eaccpf:cpfDescription/eaccpf:identity[eaccpf:entityType='person']/eaccpf:entityId">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'employee_id', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
  </xsl:template>

  <!-- *** COH - MODS citations *** -->
  <xsl:template match="mods:mods" mode="CoH" name="index_mods_for_CoH" >
    <!-- defaults -->
    <xsl:param name="prefix">coh_search_</xsl:param>
    <xsl:param name="suffix"></xsl:param>

    <!-- Topic and Notes -->
    <xsl:for-each select="./mods:subject/mods:topic[not(@type)][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'topic_and_notes', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select="./mods:note[not(@type)][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'topic_and_notes', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select="./mods:subject/mods:name[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'topic_and_notes', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Book Authors -->
    <xsl:for-each select="./mods:relatedItem[@type='host']/mods:name/mods:role/mods:roleTerm['author']/../../mods:namePart[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'book_authors', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Conference -->
    <xsl:for-each select="./mods:titleInfo[@type='conference']/mods:title[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'conference', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Editor  -->
    <xsl:for-each select="./mods:name[@type='personal']/mods:role[roleTerm='editor']/../mods:namePart[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'editor', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Full Journal Title -->
    <xsl:for-each select="./mods:relatedItem[@type='host']/mods:titleInfo[not(@type)]/mods:title[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'full_journal_title', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- MeSH -->
    <xsl:for-each select="./mods:subject[@authority='mesh']/mods:topic[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'mesh_terms', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Peer Review -->
    <xsl:for-each select="./mods:note[@type='peer reviewed'][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'peer_reviewed', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Keywords -->
    <xsl:for-each select="./mods:subject[not(@type)]/mods:topic[not(@type)][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'keywords', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select="./mods:subject[not(@type)]/mods:name[not(@type)][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'keywords', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Secondary Source ID -->
    <xsl:for-each select="./mods:identifier[@displayLabel='Accession Number'][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'secondary_source_id', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Status -->
    <xsl:for-each select="./mods:note[@type='pubmedStatus'][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'status', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Funding Agency -->
    <xsl:for-each select="./mods:name[@type='corporate']/mods:role[mods:roleTerm[@type='text']='funding agency']/../mods:namePart[normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'funding_agency', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Grant Number -->
    <xsl:for-each select="./mods:name[@type='corporate']/mods:role[mods:roleTerm[@type='text']='funding agency']/../mods:description[@type='grant number'][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'grant_number', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>

    <!-- Cores -->
    <xsl:for-each select="./mods:note[@type='core facilities'][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'cores', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
  </xsl:template>
  <!-- *** End COH *** -->

  <xsl:template match="rdf:RDF">
    <xsl:param name="prefix">rels_</xsl:param>
    <xsl:param name="suffix">_s</xsl:param>

    <xsl:for-each select=".//rdf:Description/*[@rdf:resource]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_uri', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@rdf:resource"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select=".//rdf:Description/*[not(@rdf:resource)][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_literal', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
  </xsl:template>

  <!-- Basic EAC-CPF -->
  <xsl:template match="eaccpf:eac-cpf">
        <xsl:param name="pid"/>
        <xsl:param name="dsid" select="'EAC-CPF'"/>
        <xsl:param name="prefix" select="'eaccpf_'"/>
        <xsl:param name="suffix" select="'_et'"/> <!-- 'edged' (edge n-gram) text, for auto-completion -->

        <xsl:variable name="cpfDesc" select="eaccpf:cpfDescription"/>
        <xsl:variable name="identity" select="$cpfDesc/eaccpf:identity"/>
        <xsl:variable name="name_prefix" select="concat($prefix, 'name_')"/>
        <!-- ensure that the primary is first -->
        <xsl:apply-templates select="$identity/eaccpf:nameEntry[@localType='primary']">
            <xsl:with-param name="pid" select="$pid"/>
            <xsl:with-param name="prefix" select="$name_prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>

        <!-- place alternates (non-primaries) later -->
        <xsl:apply-templates select="$identity/eaccpf:nameEntry[not(@localType='primary')]">
            <xsl:with-param name="pid" select="$pid"/>
            <xsl:with-param name="prefix" select="$name_prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>
    </xsl:template>

  <xsl:template match="eaccpf:nameEntry">
    <xsl:param name="pid"/>
    <xsl:param name="prefix">eaccpf_name_</xsl:param>
    <xsl:param name="suffix">_et</xsl:param>

    <!-- fore/first name -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'given', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="part[@localType='middle']">
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(eaccpf:part[@localType='forename'])"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>

    <!-- sur/last name -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'family', $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="normalize-space(eaccpf:part[@localType='surname'])"/>
    </field>

    <!-- id -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'id', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="@id">
          <xsl:value-of select="concat($pid, '/', @id)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($pid,'/name_position:', position())"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>

    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'complete', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="normalize-space(part[@localType='middle'])">
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename']))"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>
  </xsl:template>

  <xsl:template name="get_ISO8601_date">
    <xsl:param name="date"/>
    <xsl:message><xsl:value-of select="$date"/></xsl:message>

    <xsl:variable name="pattern1">
      <xsl:variable name="frac">([.,][0-9]+)</xsl:variable>
      <xsl:variable name="sec_el">(\:[0-9]{2}<xsl:value-of select="$frac"/>?)</xsl:variable>
      <xsl:variable name="min_el">(\:[0-9]{2}(<xsl:value-of select="$frac"/>|<xsl:value-of select="$sec_el"/>?))</xsl:variable>
      <xsl:variable name="time_el">([0-9]{2}(<xsl:value-of select="$frac"/>|<xsl:value-of select="$min_el"/>))</xsl:variable>
      <xsl:variable name="time_offset">(Z|[+-]<xsl:value-of select="$time_el"/>)</xsl:variable>
      <xsl:variable name="time_pattern">(T<xsl:value-of select="$time_el"/><xsl:value-of select="$time_offset"/>?)</xsl:variable>

      <xsl:variable name="day_el">(-[0-9]{2})</xsl:variable>
      <xsl:variable name="month_el">(-[0-9]{2}<xsl:value-of select="$day_el"/>?)</xsl:variable>
      <xsl:variable name="date_el">([0-9]{4}<xsl:value-of select="$month_el"/>?)</xsl:variable>
      <xsl:variable name="date_opt_pattern">(<xsl:value-of select="$date_el"/><xsl:value-of select="$time_pattern"/>?)</xsl:variable>
      <!--xsl:text>(<xsl:value-of select="$time_pattern"/> | <xsl:value-of select="$date_opt_pattern"/>)</xsl:text-->
      <xsl:value-of select="$date_opt_pattern"/>
    </xsl:variable>

    <xsl:variable name="pattern2">([0-9]{1,2}/)([0-9]{1,2}/)([0-9]{4})</xsl:variable>
    <xsl:variable name="pattern3">([0-9]{1,2}/)?([0-9]{1,2}/)?([0-9]{4}) ([0-9]{1,2}:[0-9]{2})</xsl:variable>

    <!-- XXX: need to add the joda jar to the lib directory to make work? -->

    <xsl:variable name="parsed">
      <xsl:choose>
        <xsl:when test="java:matches($date, $pattern2)">
          <xsl:variable name="dp" select="java:org.joda.time.format.DateTimeFormat.forPattern('M/d/y')"/>
          <xsl:value-of select="java:parseDateTime($dp, $date)"/>
        </xsl:when>
        <xsl:when test="java:matches($date, $pattern3)">
          <xsl:variable name="dp" select="java:org.joda.time.format.DateTimeFormat.forPattern('M/d/y H:m')"/>
          <xsl:value-of select="java:parseDateTime($dp, $date)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$date"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="asdf" select="string($parsed)"/>
    <xsl:message><xsl:value-of select="$asdf"/></xsl:message>
    <xsl:choose>
    <xsl:when test="java:matches($asdf, $pattern1)">
      <xsl:variable name="dp" select="java:org.joda.time.format.ISODateTimeFormat.dateTimeParser()"/>

      <!--<xsl:message><xsl:value-of select="java:parseDateTime($dp, $parsed)"/></xsl:message>-->
      <xsl:variable name="f" select="java:org.joda.time.format.ISODateTimeFormat.dateTime()"/>
      <xsl:variable name="df" select="java:withZoneUTC($f)"/>
      <xsl:value-of select="java:print($df, java:parseDateTime($dp, $asdf))"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message><xsl:value-of select="$parsed"/></xsl:message>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- Create fields for the set of selected elements, named according to the 'local-name' and containing the 'text' -->
  <xsl:template match="*" mode="simple_set">
    <xsl:param name="prefix">changeme_</xsl:param>
    <xsl:param name="suffix">_t</xsl:param>

    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="text()"/>
    </field>
  </xsl:template>

    <!-- an example of handling a managed datastream-->
    <!--<xsl:template name="TEI">
    <xsl:variable name="PROT">
    http
    </xsl:variable>
    <xsl:variable name="FEDORAUSERNAME">
    fedoraAdmin
    </xsl:variable>
    <xsl:variable name="FEDORAPASSWORD">
    anonymous
    </xsl:variable>
    <xsl:variable name="HOST">
    test.testy.edu
    </xsl:variable>
    <xsl:variable name="PORT">
    8080
    </xsl:variable>
    <xsl:variable name="TEI"
    select="document(concat($PROT, '://', $FEDORAUSERNAME, ':', $FEDORAPASSWORD, '@', $HOST, ':', $PORT, '/fedora/objects/', $PID, '/datastreams/', 'TEI', '/content'))" />

    <xsl:for-each select="$TEI//tei:surname[text()]">
    <field>
    <xsl:attribute name="name">
    <xsl:value-of select="concat('tei_', 'surname_s')" />
    </xsl:attribute>
    <xsl:value-of select="normalize-space(text())" />
    </field>
    </xsl:for-each>
    <xsl:for-each select="$TEI//tei:placeName/*[text()]">
    <field>
    <xsl:attribute name="name">
    <xsl:value-of select="concat('tei_', 'placeName_s')" />
    </xsl:attribute>
    <xsl:value-of select="normalize-space(text())" />
    </field>
    </xsl:for-each>
    <xsl:for-each select="$TEI//tei:orgName[text()]">
    <field>
    <xsl:attribute name="name">
    <xsl:value-of select="concat('tei_', 'orgName_s')" />
    </xsl:attribute>
    <xsl:value-of select="normalize-space(text())" />
    </field>
    </xsl:for-each>

    </xsl:template>-->

</xsl:stylesheet>

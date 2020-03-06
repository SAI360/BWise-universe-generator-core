create  view [dbo].[V_DM_COLUMNS] as
WITH REC AS
(
  SELECT
    C.CLASSDEFID
    ,C.NAME CLASSNAME
    ,C.SUPERCLASS
    ,C.CLASSDEFID CHILDID
    ,C.NAME CHILDNAME
,c.CUSTOMIZED
  FROM M_CLASSDEF C

  UNION ALL
  SELECT
    C.CLASSDEFID
    ,C.NAME CLASSNAME
    ,C.SUPERCLASS
    ,REC.CHILDID
    ,REC.CHILDNAME
    ,c.CUSTOMIZED
  FROM M_CLASSDEF C

  INNER JOIN REC
  ON C.CLASSDEFID = REC.SUPERCLASS
),

ROOT_CLASSES AS (
  SELECT
    RT.CHILDID
    ,RT.CHILDNAME
    ,RT.CLASSNAME
  FROM REC RT

  WHERE RT.CLASSNAME = 'Issue'
  OR RT.CLASSNAME = 'AbstractGroup'
  OR RT.CLASSNAME = 'Loss'
  OR RT.CLASSNAME = 'EnumLiteral'
  OR RT.CLASSNAME = 'AbstractInformationComponent'
  OR RT.CLASSNAME = 'BWAbstractAssessment'
  OR RT.CLASSNAME = 'BWAbstractAssessmentSession'
  OR RT.CLASSNAME = 'BWAbstractAnswer'
  OR RT.CLASSNAME = 'AbstractFolder'
  OR RT.CLASSNAME = 'AbstractCategory'
),


ID_ATTRIBUTES AS (
  SELECT
    C.NAME CLASSNAME
    ,RT.CLASSNAME ROOTCLASS
    ,'T_' + UPPER(C.NAME) TABLENAME
    ,UPPER(C.NAME) + 'ID' COLUMNNAME
    ,'id' ATTRIBUTE
    ,'ID' LABEL
    ,'PRIMARY_KEY' TYPE
    ,'ID' COLUMNTYPE
    ,0 ISMULTIPLE
    ,0 ISHIDDEN
    ,0 ISDIVISIONSPECIFIC
    ,C.NAME LINKCLASSNAME
    ,RT.CLASSNAME LINKROOTCLASS
    ,-100 SEQUENCENUMBER
, c.CUSTOMIZED
  FROM M_CLASSDEF C

  LEFT JOIN ROOT_CLASSES RT
  ON C.CLASSDEFID = RT.CHILDID

  UNION ALL
  SELECT
    C.NAME CLASSNAME
    ,RT.CLASSNAME ROOTCLASS
    ,'T_' + UPPER(C.NAME) TABLENAME
    ,UPPER(C.NAME) + 'BWID' COLUMNNAME
    ,'bwId' ATTRIBUTE
    ,'BWID' LABEL
    ,'STRING' TYPE
    ,'VALUE' COLUMNTYPE
    ,0 ISMULTIPLE
    ,0 ISHIDDEN
    ,0 ISDIVISIONSPECIFIC
    ,NULL LINKCLASSNAME
    ,NULL LINKROOTCLASS
    ,-99 SEQUENCENUMBER
	, c.CUSTOMIZED
  FROM M_CLASSDEF C

  LEFT JOIN ROOT_CLASSES RT
  ON C.CLASSDEFID = RT.CHILDID
),

EXTRA_CLASS_ATTRIBUTES AS (
  SELECT
    C.NAME CLASSNAME
    ,RT.CLASSNAME ROOTCLASS
    ,'T_' + UPPER(C.NAME) TABLENAME
    ,'DISPLAYSTRING' COLUMNNAME
    ,'displaystring' ATTRIBUTE
    ,'Display String' LABEL
    ,'STRING' TYPE
    ,'VALUE' COLUMNTYPE
    ,0 ISMULTIPLE
    ,0 ISHIDDEN
    ,0 ISDIVISIONSPECIFIC
    ,NULL LINKCLASSNAME
    ,NULL LINKROOTCLASS
    ,-98 SEQUENCENUMBER
,c.CUSTOMIZED
  FROM M_CLASSDEF C

  LEFT JOIN ROOT_CLASSES RT
  ON C.CLASSDEFID = RT.CHILDID

  WHERE RT.CLASSNAME IS NULL OR RT.CLASSNAME <> 'BWAbstractAssessmentSession'
),

ATTRIBUTES AS (
  SELECT
    ID_ATTR.*
		, NULL ISMULTILANG
  FROM ID_ATTRIBUTES ID_ATTR

  WHERE ID_ATTR.CLASSNAME NOT LIKE '*%'

  UNION ALL
  SELECT
    EXT_ATTR.*
	, NULL ISMULTILANG
  FROM EXTRA_CLASS_ATTRIBUTES EXT_ATTR

  WHERE EXT_ATTR.CLASSNAME NOT LIKE '*%'

  UNION ALL
  SELECT
    REC.CHILDNAME CLASSNAME
    ,RT.CLASSNAME ROOTCLASS
    ,CASE WHEN A.UPPERMULTIPLICITY > 1 AND T.DISCRIMINATOR = 'INSTANCE' THEN 'X_' + UPPER(REC.CHILDNAME) + '_' + UPPER(O.NAME) ELSE 'T_' + UPPER(REC.CHILDNAME) END TABLENAME
    ,CASE
      WHEN RT.CLASSNAME = 'EnumLiteral' AND O.NAME = 'name' THEN 'IDENTIFIER'
      WHEN (RT.CLASSNAME = 'AbstractGroup' OR REC.CHILDNAME IN ('Resource', 'Role')) AND O.NAME = 'superior' THEN 'PARENTOBJECT' + TMP.SUFFIX
      ELSE CASE WHEN A.UPPERMULTIPLICITY > 1 AND T.DISCRIMINATOR = 'INSTANCE' THEN UPPER('RELATED' + COALESCE(TMP.SUFFIX, '')) ELSE UPPER(O.NAME + COALESCE(TMP.SUFFIX, '')) END
    END COLUMNNAME
    ,O.NAME ATTRIBUTE
    ,LO.LABEL LABEL
    ,COALESCE(TMP.NEWTYPE, T.DISCRIMINATOR) TYPE
    ,COALESCE(TMP.COLUMNTYPE, 'VALUE') COLUMNTYPE
    ,CASE WHEN A.UPPERMULTIPLICITY > 1 AND T.DISCRIMINATOR = 'INSTANCE' THEN 1 ELSE 0 END ISMULTIPLE
    ,CASE WHEN A.ISHIDDEN = 'Y' THEN 1 ELSE 0 END ISHIDDEN
    ,CASE WHEN A.ISDIVISIONSPECIFIC = 'Y' THEN 1 ELSE 0 END ISDIVISIONSPECIFIC
    ,RC.NAME LINKCLASSNAME
    ,RCT.CLASSNAME LINKROOTCLASS
    ,(A.SEQUENCENUMBER + 10) * 10 + (CASE WHEN TMP.SEQUENCENUMBER IS NOT NULL THEN TMP.SEQUENCENUMBER ELSE 0 END) SEQUENCENUMBER
	,rec.CUSTOMIZED 
    , T.ISMULTILANG
     FROM REC

  INNER JOIN MX_CLASSDEFXATTRIBDEF XA
  ON REC.CLASSDEFID = XA.CLASSDEFID

  INNER JOIN M_ATTRIBUTEDEF A
  ON XA.ATTRIBUTEDEFID = A.ATTRIBUTEDEFID

  INNER JOIN M_METAMODELOBJECT O
  ON XA.ATTRIBUTEDEFID = O.METAMODEL_OBJECTID

  INNER JOIN L_METAMODELOBJECT LO
  ON XA.ATTRIBUTEDEFID = LO.METAMODEL_OBJECTID
  AND LO.LANGUAGEID = (select languageid from M_SYSTEMLANGUAGE where name = 'en')

  INNER JOIN M_TYPEDEF T
  ON A.TYPEDEFID = T.TYPEDEFID

  INNER JOIN (
    SELECT
      REC.CHILDID
      ,CASE WHEN COUNT(O.NAME) OVER (PARTITION BY REC.CHILDID, O.NAME) = 1 OR A.ISOVERRIDE = 'Y' THEN CASE WHEN MAX(REC.CLASSDEFID) OVER (PARTITION BY REC.CHILDID, O.NAME) = REC.CLASSDEFID THEN XA.ATTRIBUTEDEFID END ELSE NULL END ATTRIBUTEDEFID
    FROM REC

    INNER JOIN MX_CLASSDEFXATTRIBDEF XA
    ON REC.CLASSDEFID = XA.CLASSDEFID

    INNER JOIN M_ATTRIBUTEDEF A
    ON XA.ATTRIBUTEDEFID = A.ATTRIBUTEDEFID

    INNER JOIN M_METAMODELOBJECT O
    ON XA.ATTRIBUTEDEFID = O.METAMODEL_OBJECTID
  ) ACTIVEATTRIBUTE
  ON XA.ATTRIBUTEDEFID = ACTIVEATTRIBUTE.ATTRIBUTEDEFID
  AND REC.CHILDID = ACTIVEATTRIBUTE.CHILDID

  LEFT JOIN (
  SELECT
    XI.INSTANCETYPEDEFID
    ,COUNT(XI.CLASSDEFID) NUMRELATIONS
  FROM MX_INSTANCETYPETOCLASS XI

  GROUP BY XI.INSTANCETYPEDEFID
  ) XTC
  ON A.TYPEDEFID = XTC.INSTANCETYPEDEFID

  LEFT JOIN MX_INSTANCETYPETOCLASS XI
  ON A.TYPEDEFID = XI.INSTANCETYPEDEFID

  LEFT JOIN M_CLASSDEF RC
  ON XI.CLASSDEFID = RC.CLASSDEFID

  LEFT JOIN ROOT_CLASSES RCT
  ON RC.CLASSDEFID = RCT.CHILDID

  LEFT JOIN (
    SELECT 'INSTANCE' TYPE, 'FOREIGN_KEY' NEWTYPE, 'ID' COLUMNTYPE, 'ID' SUFFIX, 1 SEQUENCENUMBER
    UNION ALL SELECT 'INSTANCE' TYPE, 'STRING' NEWTYPE, 'VALUE' COLUMNTYPE, 'NAME' SUFFIX, 0 SEQUENCENUMBER
    UNION ALL SELECT 'INSTANCE' TYPE, 'STRING' NEWTYPE, 'TYPE' COLUMNTYPE, 'TYPE' SUFFIX, 2 SEQUENCENUMBER
  ) TMP
  ON T.DISCRIMINATOR = TMP.TYPE
  AND NOT (TMP.COLUMNTYPE = 'TYPE' AND XTC.NUMRELATIONS < 2
    AND RC.NAME != 'AbstractGroup'
    AND RC.NAME != 'Group'
    AND RC.NAME != 'BWSubject'
  )

  LEFT JOIN ROOT_CLASSES RT
  ON REC.CHILDID = RT.CHILDID

  WHERE A.ISHIDDEN = 'N'
  AND REC.CHILDNAME NOT LIKE '*%'
),

COLS AS (
  SELECT DISTINCT
    ATTR.CLASSNAME
    ,ATTR.ROOTCLASS
    ,ATTR.TABLENAME
    ,ATTR.COLUMNNAME
    ,ATTR.ATTRIBUTE
    ,ATTR.LABEL
    ,ATTR.TYPE
    ,ATTR.COLUMNTYPE
    ,ATTR.ISMULTIPLE
    ,ATTR.ISHIDDEN
    ,ATTR.ISDIVISIONSPECIFIC
    ,NULL DWHTABLENAMESUFFIX
    ,NULL RISKDIMENSION
    ,NULL RISKPHASE
    ,NULL HEATMAPNAME
    ,NULL HEATMAPQUESTION
    ,ATTR.SEQUENCENUMBER
, ATTR.ISMULTILANG
,ATTR.LINKCLASSNAME
  FROM ATTRIBUTES ATTR
),


ALL_COLUMNS AS (
  SELECT
    C.*
  FROM COLS C

)

-----------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

SELECT top 1000000000 NULL AS DUMMY, * FROM ALL_COLUMNS

 --WHERE CLASSNAME = 'eUniverse'

ORDER BY SEQUENCENUMBER
GO


right_recovery()
{
    local GRANT_USER=`echo $DB_USER|tr a-z A-Z`
    local db_name=`echo $DB_NAME|tr a-z A-Z`
        su - dbadmin -c "gsql -d $db_name <<XXXEOFXXX
            set client_min_messages = error;
            REVOKE ALL ON PG_TYPE FROM PUBLIC;
            REVOKE ALL ON PG_FOREIGN_TABLE FROM PUBLIC;
            REVOKE ALL ON PG_ROLES FROM PUBLIC;
            REVOKE ALL ON DUAL FROM PUBLIC;
            REVOKE ALL ON PG_GROUP FROM PUBLIC;
            REVOKE ALL ON PG_USER FROM PUBLIC;
            REVOKE ALL ON PG_RULES  FROM PUBLIC;
            REVOKE ALL ON PG_VIEWS  FROM PUBLIC;
            REVOKE ALL ON PG_TABLES  FROM PUBLIC;
            REVOKE ALL ON PG_INDEXES             FROM PUBLIC;
            REVOKE ALL ON PG_STATS                           FROM PUBLIC;
            REVOKE ALL ON PG_LOCKS                           FROM PUBLIC;
            REVOKE ALL ON PG_CURSORS                         FROM PUBLIC;
            REVOKE ALL ON PG_AVAILABLE_EXTENSIONS            FROM PUBLIC;
            REVOKE ALL ON PG_AVAILABLE_EXTENSION_VERSIONS    FROM PUBLIC;
            REVOKE ALL ON PG_PREPARED_XACTS                  FROM PUBLIC;
            REVOKE ALL ON PG_PREPARED_STATEMENTS             FROM PUBLIC;
            REVOKE ALL ON PG_SECLABELS                       FROM PUBLIC;
            REVOKE ALL ON PG_SETTINGS                        FROM PUBLIC;
            REVOKE ALL ON PG_TIMEZONE_ABBREVS                FROM PUBLIC;
            REVOKE ALL ON PG_TIMEZONE_NAMES                  FROM PUBLIC;
            REVOKE ALL ON PG_STAT_ALL_TABLES                 FROM PUBLIC;
            REVOKE ALL ON PG_STAT_XACT_ALL_TABLES            FROM PUBLIC;
            REVOKE ALL ON PG_STAT_SYS_TABLES                 FROM PUBLIC;
            REVOKE ALL ON PG_STAT_XACT_SYS_TABLES            FROM PUBLIC;
            REVOKE ALL ON PG_STAT_USER_TABLES                FROM PUBLIC;
            REVOKE ALL ON PG_STAT_XACT_USER_TABLES           FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_ALL_TABLES               FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_SYS_TABLES               FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_USER_TABLES              FROM PUBLIC;
            REVOKE ALL ON PG_STAT_ALL_INDEXES                FROM PUBLIC;
            REVOKE ALL ON PG_STAT_SYS_INDEXES                FROM PUBLIC;
            REVOKE ALL ON PG_STAT_USER_INDEXES               FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_ALL_INDEXES              FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_SYS_INDEXES              FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_USER_INDEXES             FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_ALL_SEQUENCES            FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_SYS_SEQUENCES            FROM PUBLIC;
            REVOKE ALL ON PG_STAT_DATABASE                   FROM PUBLIC;
            REVOKE ALL ON PG_STAT_DATABASE_CONFLICTS         FROM PUBLIC;
            REVOKE ALL ON PG_STAT_USER_FUNCTIONS             FROM PUBLIC;
            REVOKE ALL ON PG_STAT_XACT_USER_FUNCTIONS        FROM PUBLIC;
            REVOKE ALL ON PG_STAT_BGWRITER                   FROM PUBLIC;
            REVOKE ALL ON PG_USER_MAPPINGS                   FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_OBJECTS                        FROM PUBLIC;
            REVOKE ALL ON PG_CATALOG.ALL_OBJECTS             FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_OBJECTS             FROM PUBLIC;
            REVOKE ALL ON ALL_USERS                          FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_USERS                          FROM PUBLIC;
            REVOKE ALL ON ALL_SEQUENCES                      FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_SEQUENCES                      FROM PUBLIC;
            REVOKE ALL ON ALL_ALL_TABLES                     FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_ALL_TABLES                     FROM PUBLIC;
            REVOKE ALL ON ALL_TABLES                         FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_TABLES                     FROM PUBLIC;
            REVOKE ALL ON USER_OBJECTS                       FROM PUBLIC;
            REVOKE ALL ON SYS.USER_OBJECTS                   FROM PUBLIC;
            REVOKE ALL ON ALL_DIRECTORIES                    FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_DIRECTORIES                FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_DIRECTORIES                    FROM PUBLIC;
            REVOKE ALL ON ALL_SOURCE                         FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_SOURCE                     FROM PUBLIC;
            REVOKE ALL ON ALL_DEPENDENCIES                   FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_DEPENDENCIES               FROM PUBLIC;
            REVOKE ALL ON ALL_VIEWS                          FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_VIEWS                      FROM PUBLIC;
            REVOKE ALL ON ALL_PROCEDURES                     FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_PROCEDURES                 FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_TAB_COLUMNS                    FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_SOURCE                         FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_PROCEDURES                     FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_SEQUENCES                      FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_TRIGGERS                       FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_VIEWS                          FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_INDEXES                        FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_TABLES                         FROM PUBLIC;
            REVOKE ALL ON DBA_TABLES_2                       FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_TABLESPACES                    FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_USERS                          FROM PUBLIC;
            REVOKE ALL ON USER_TAB_COLUMNS                   FROM PUBLIC;
            REVOKE ALL ON SYS.USER_TAB_COLUMNS               FROM PUBLIC;
            REVOKE ALL ON USER_PROCEDURES                    FROM PUBLIC;
            REVOKE ALL ON SYS.USER_PROCEDURES                    FROM PUBLIC;
            REVOKE ALL ON USER_SOURCE                        FROM PUBLIC;
            REVOKE ALL ON SYS.USER_SOURCE                        FROM PUBLIC;
            REVOKE ALL ON USER_SEQUENCES                     FROM PUBLIC;
            REVOKE ALL ON SYS.USER_SEQUENCES                     FROM PUBLIC;
            REVOKE ALL ON USER_TABLES                        FROM PUBLIC;
            REVOKE ALL ON SYS.USER_TABLES                        FROM PUBLIC;
            REVOKE ALL ON USER_INDEXES                       FROM PUBLIC;
            REVOKE ALL ON SYS.USER_INDEXES                       FROM PUBLIC;
            REVOKE ALL ON USER_TRIGGERS                      FROM PUBLIC;
            REVOKE ALL ON SYS.USER_TRIGGERS                      FROM PUBLIC;
            REVOKE ALL ON USER_VIEWS                         FROM PUBLIC;
            REVOKE ALL ON SYS.USER_VIEWS                         FROM PUBLIC;
            REVOKE ALL ON information_schema.CONSTRAINT_TABLE_USAGE             FROM PUBLIC;
            REVOKE ALL ON information_schema.DOMAIN_CONSTRAINTS                 FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_DATA_FILES                     FROM PUBLIC;
            REVOKE ALL ON PG_AUTHID_VIEW                     FROM PUBLIC;
            REVOKE ALL ON SYS.USER_TABLESPACES                   FROM PUBLIC;
            REVOKE ALL ON PG_DATABASE_VIEW                   FROM PUBLIC;
            REVOKE ALL ON information_schema.DOMAIN_UDT_USAGE                   FROM PUBLIC;
            REVOKE ALL ON USER_TABLESPACES                   FROM PUBLIC;
            REVOKE ALL ON ALL_COL_COMMENTS                   FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_COL_COMMENTS                   FROM PUBLIC;
            REVOKE ALL ON ALL_TAB_COLUMNS                    FROM PUBLIC;
            REVOKE ALL ON SYS.ALL_TAB_COLUMNS                    FROM PUBLIC;
            REVOKE ALL ON USER_JOBS                          FROM PUBLIC;
            REVOKE ALL ON information_schema.CONSTRAINT_COLUMN_USAGE            FROM PUBLIC;
            REVOKE ALL ON SYS.USER_JOBS                          FROM PUBLIC;
            REVOKE ALL ON SYS.DBA_JOBS                           FROM PUBLIC;
            REVOKE ALL ON PG_ATTRIBUTE                       FROM PUBLIC;
            REVOKE ALL ON PG_JOB_VIEW                        FROM PUBLIC;
            REVOKE ALL ON PG_PROC                            FROM PUBLIC;
            REVOKE ALL ON PG_JOBOID_VIEW                     FROM PUBLIC;
            REVOKE ALL ON PG_JOB_PROC_VIEW                   FROM PUBLIC;
            REVOKE ALL ON PG_JOB_SCHEDULE_VIEW               FROM PUBLIC;
            REVOKE ALL ON PG_CLASS                           FROM PUBLIC;
            REVOKE ALL ON PG_DATABASE                        FROM PUBLIC;
            REVOKE ALL ON PG_CONSTRAINT                      FROM PUBLIC;
            REVOKE ALL ON PG_INHERITS                        FROM PUBLIC;
            REVOKE ALL ON PG_INDEX                           FROM PUBLIC;
            REVOKE ALL ON PG_OPERATOR                        FROM PUBLIC;
            REVOKE ALL ON PG_OPFAMILY                        FROM PUBLIC;
            REVOKE ALL ON PG_OPCLASS                         FROM PUBLIC;
            REVOKE ALL ON PG_AM                              FROM PUBLIC;
            REVOKE ALL ON PG_AMOP                            FROM PUBLIC;
            REVOKE ALL ON PG_AMPROC                          FROM PUBLIC;
            REVOKE ALL ON PG_LANGUAGE                        FROM PUBLIC;
            REVOKE ALL ON PG_LARGEOBJECT_METADATA            FROM PUBLIC;
            REVOKE ALL ON PG_AGGREGATE                       FROM PUBLIC;
            REVOKE ALL ON PG_REWRITE                         FROM PUBLIC;
            REVOKE ALL ON PG_TRIGGER                         FROM PUBLIC;
            REVOKE ALL ON PG_DESCRIPTION                     FROM PUBLIC;
            REVOKE ALL ON PG_CAST                            FROM PUBLIC;
            REVOKE ALL ON PG_ENUM                            FROM PUBLIC;
            REVOKE ALL ON PG_NAMESPACE                       FROM PUBLIC;
            REVOKE ALL ON PG_CONVERSION                      FROM PUBLIC;
            REVOKE ALL ON PG_DEPEND                          FROM PUBLIC;
            REVOKE ALL ON PG_DB_ROLE_SETTING                 FROM PUBLIC;
            REVOKE ALL ON PG_TABLESPACE                      FROM PUBLIC;
            REVOKE ALL ON PG_PLTEMPLATE                      FROM PUBLIC;
            REVOKE ALL ON PG_STATIO_USER_SEQUENCES           FROM PUBLIC;
            REVOKE ALL ON PG_STAT_ACTIVITY                   FROM PUBLIC;
            REVOKE ALL ON PG_STAT_REPLICATION                FROM PUBLIC;
            REVOKE ALL ON information_schema.INFORMATION_SCHEMA_CATALOG_NAME    FROM PUBLIC;
            REVOKE ALL ON information_schema.APPLICABLE_ROLES                   FROM PUBLIC;
            REVOKE ALL ON information_schema.ADMINISTRABLE_ROLE_AUTHORIZATIONS  FROM PUBLIC;
            REVOKE ALL ON information_schema.ATTRIBUTES                         FROM PUBLIC;
            REVOKE ALL ON information_schema.CHARACTER_SETS                     FROM PUBLIC;
            REVOKE ALL ON information_schema.CHECK_CONSTRAINT_ROUTINE_USAGE     FROM PUBLIC;
            REVOKE ALL ON information_schema.CHECK_CONSTRAINTS                  FROM PUBLIC;
            REVOKE ALL ON information_schema.COLLATIONS                         FROM PUBLIC;
            REVOKE ALL ON information_schema.COLLATION_CHARACTER_SET_APPLICABILITY FROM PUBLIC;
            REVOKE ALL ON PG_SHDEPEND                        FROM PUBLIC;
            REVOKE ALL ON PG_SHDESCRIPTION                   FROM PUBLIC;
            REVOKE ALL ON PG_TS_CONFIG                       FROM PUBLIC;
            REVOKE ALL ON PG_TS_CONFIG_MAP                   FROM PUBLIC;
            REVOKE ALL ON PG_TS_DICT                         FROM PUBLIC;
            REVOKE ALL ON PG_TS_PREFERENCE                   FROM PUBLIC;
            REVOKE ALL ON PG_TS_GIN                          FROM PUBLIC;
            REVOKE ALL ON PG_TS_PARSER                       FROM PUBLIC;
            REVOKE ALL ON PG_TS_TEMPLATE                     FROM PUBLIC;
            REVOKE ALL ON PG_EXTENSION                       FROM PUBLIC;
            REVOKE ALL ON PG_FOREIGN_DATA_WRAPPER            FROM PUBLIC;
            REVOKE ALL ON PG_FOREIGN_SERVER                  FROM PUBLIC;
            REVOKE ALL ON PG_DEFAULT_ACL                     FROM PUBLIC;
            REVOKE ALL ON PG_SECLABEL                        FROM PUBLIC;
            REVOKE ALL ON PG_SHSECLABEL                      FROM PUBLIC;
            REVOKE ALL ON PG_COLLATION                       FROM PUBLIC;
            REVOKE ALL ON PG_RANGE                           FROM PUBLIC;
            REVOKE ALL ON PG_PARTDEF                         FROM PUBLIC;
            REVOKE ALL ON PG_PARTITION                       FROM PUBLIC;
            REVOKE ALL ON PG_JOB                             FROM PUBLIC;
            REVOKE ALL ON PG_JOB_PROC                        FROM PUBLIC;
            REVOKE ALL ON PG_JOB_SCHEDULE                    FROM PUBLIC;
            REVOKE ALL ON PG_DIRECTORY                       FROM PUBLIC;
            REVOKE ALL ON information_schema.COLUMN_DOMAIN_USAGE                FROM PUBLIC;
            REVOKE ALL ON information_schema.COLUMN_PRIVILEGES                  FROM PUBLIC;
            REVOKE ALL ON information_schema.COLUMN_UDT_USAGE                   FROM PUBLIC;
            REVOKE ALL ON information_schema.COLUMNS                            FROM PUBLIC;
            REVOKE ALL ON information_schema.DOMAINS                            FROM PUBLIC;
            REVOKE ALL ON information_schema.ENABLED_ROLES                      FROM PUBLIC;
            REVOKE ALL ON information_schema.KEY_COLUMN_USAGE                   FROM PUBLIC;
            REVOKE ALL ON information_schema.PARAMETERS                         FROM PUBLIC;
            REVOKE ALL ON information_schema.REFERENTIAL_CONSTRAINTS            FROM PUBLIC;
            REVOKE ALL ON information_schema.ROLE_COLUMN_GRANTS                 FROM PUBLIC;
            REVOKE ALL ON information_schema.ROUTINE_PRIVILEGES                 FROM PUBLIC;
            REVOKE ALL ON information_schema.ROLE_ROUTINE_GRANTS                FROM PUBLIC;
            REVOKE ALL ON information_schema.ROUTINES                           FROM PUBLIC;
            REVOKE ALL ON information_schema.SCHEMATA                           FROM PUBLIC;
            REVOKE ALL ON information_schema.SEQUENCES                          FROM PUBLIC;
            REVOKE ALL ON information_schema.TABLE_CONSTRAINTS                  FROM PUBLIC;
            REVOKE ALL ON information_schema.TABLE_PRIVILEGES                   FROM PUBLIC;
            REVOKE ALL ON information_schema.ROLE_TABLE_GRANTS                  FROM PUBLIC;
            REVOKE ALL ON information_schema.TABLES                             FROM PUBLIC;
            REVOKE ALL ON information_schema.SQL_IMPLEMENTATION_INFO            FROM PUBLIC;
            REVOKE ALL ON information_schema.SQL_LANGUAGES                      FROM PUBLIC;
            REVOKE ALL ON information_schema.SQL_PACKAGES                       FROM PUBLIC;
            REVOKE ALL ON information_schema.SQL_SIZING                         FROM PUBLIC;
            REVOKE ALL ON information_schema.SQL_SIZING_PROFILES                FROM PUBLIC;
            REVOKE ALL ON information_schema.TRIGGERED_UPDATE_COLUMNS           FROM PUBLIC;
            REVOKE ALL ON information_schema.TRIGGERS                           FROM PUBLIC;
            REVOKE ALL ON information_schema.UDT_PRIVILEGES                     FROM PUBLIC;
            REVOKE ALL ON information_schema.ROLE_UDT_GRANTS                    FROM PUBLIC;
            REVOKE ALL ON information_schema.USAGE_PRIVILEGES                   FROM PUBLIC;
            REVOKE ALL ON information_schema.ROLE_USAGE_GRANTS                  FROM PUBLIC;
            REVOKE ALL ON information_schema.USER_DEFINED_TYPES                 FROM PUBLIC;
            REVOKE ALL ON information_schema.VIEW_COLUMN_USAGE                  FROM PUBLIC;
            REVOKE ALL ON information_schema.VIEW_ROUTINE_USAGE                 FROM PUBLIC;
            REVOKE ALL ON information_schema.VIEW_TABLE_USAGE                   FROM PUBLIC;
            REVOKE ALL ON information_schema.VIEWS                              FROM PUBLIC;
            REVOKE ALL ON information_schema.DATA_TYPE_PRIVILEGES               FROM PUBLIC;
            REVOKE ALL ON information_schema.ELEMENT_TYPES                      FROM PUBLIC;
            REVOKE ALL ON information_schema.COLUMN_OPTIONS                     FROM PUBLIC;
            REVOKE ALL ON information_schema.FOREIGN_DATA_WRAPPER_OPTIONS       FROM PUBLIC;
            REVOKE ALL ON information_schema.FOREIGN_DATA_WRAPPERS              FROM PUBLIC;
            REVOKE ALL ON information_schema.FOREIGN_SERVER_OPTIONS             FROM PUBLIC;
            REVOKE ALL ON information_schema.FOREIGN_SERVERS                    FROM PUBLIC;
            REVOKE ALL ON information_schema.FOREIGN_TABLE_OPTIONS              FROM PUBLIC;
            REVOKE ALL ON information_schema.FOREIGN_TABLES                     FROM PUBLIC;
            REVOKE ALL ON information_schema.USER_MAPPING_OPTIONS               FROM PUBLIC;
            REVOKE ALL ON information_schema.USER_MAPPINGS                      FROM PUBLIC;
            REVOKE ALL ON PG_ATTRDEF                         FROM PUBLIC;
            REVOKE ALL ON PG_AUTH_MEMBERS                    FROM PUBLIC;
            REVOKE ALL ON information_schema.SQL_FEATURES                       FROM PUBLIC;
            GRANT ALL ON PG_TYPE TO $GRANT_USER;
            GRANT ALL ON PG_FOREIGN_TABLE TO $GRANT_USER;
            GRANT ALL ON PG_ROLES TO $GRANT_USER;
            GRANT ALL ON DUAL TO $GRANT_USER;
            GRANT ALL ON PG_GROUP TO $GRANT_USER;
            GRANT ALL ON PG_USER TO $GRANT_USER;
            GRANT ALL ON PG_RULES  TO $GRANT_USER;
            GRANT ALL ON PG_VIEWS  TO $GRANT_USER;
            GRANT ALL ON PG_TABLES  TO $GRANT_USER;
            GRANT ALL ON PG_INDEXES TO $GRANT_USER;
            GRANT ALL ON PG_STATS  TO $GRANT_USER;
            GRANT ALL ON PG_LOCKS  TO $GRANT_USER;
            GRANT ALL ON PG_CURSORS  TO $GRANT_USER;
            GRANT ALL ON PG_AVAILABLE_EXTENSIONS  TO $GRANT_USER;
            GRANT ALL ON PG_AVAILABLE_EXTENSION_VERSIONS    TO $GRANT_USER;
            GRANT ALL ON PG_PREPARED_XACTS                  TO $GRANT_USER;
            GRANT ALL ON PG_PREPARED_STATEMENTS             TO $GRANT_USER;
            GRANT ALL ON PG_SECLABELS                       TO $GRANT_USER;
            GRANT ALL ON PG_SETTINGS                        TO $GRANT_USER;
            GRANT ALL ON PG_TIMEZONE_ABBREVS                TO $GRANT_USER;
            GRANT ALL ON PG_TIMEZONE_NAMES                  TO $GRANT_USER;
            GRANT ALL ON PG_STAT_ALL_TABLES                 TO $GRANT_USER;
            GRANT ALL ON PG_STAT_XACT_ALL_TABLES            TO $GRANT_USER;
            GRANT ALL ON PG_STAT_SYS_TABLES                 TO $GRANT_USER;
            GRANT ALL ON PG_STAT_XACT_SYS_TABLES            TO $GRANT_USER;
            GRANT ALL ON PG_STAT_USER_TABLES                TO $GRANT_USER;
            GRANT ALL ON PG_STAT_XACT_USER_TABLES           TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_ALL_TABLES               TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_SYS_TABLES               TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_USER_TABLES              TO $GRANT_USER;
            GRANT ALL ON PG_STAT_ALL_INDEXES                TO $GRANT_USER;
            GRANT ALL ON PG_STAT_SYS_INDEXES                TO $GRANT_USER;
            GRANT ALL ON PG_STAT_USER_INDEXES               TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_ALL_INDEXES              TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_SYS_INDEXES              TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_USER_INDEXES             TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_ALL_SEQUENCES            TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_SYS_SEQUENCES            TO $GRANT_USER;
            GRANT ALL ON PG_STAT_DATABASE                   TO $GRANT_USER;
            GRANT ALL ON PG_STAT_DATABASE_CONFLICTS         TO $GRANT_USER;
            GRANT ALL ON PG_STAT_USER_FUNCTIONS             TO $GRANT_USER;
            GRANT ALL ON PG_STAT_XACT_USER_FUNCTIONS        TO $GRANT_USER;
            GRANT ALL ON PG_STAT_BGWRITER                   TO $GRANT_USER;
            GRANT ALL ON PG_USER_MAPPINGS                   TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_OBJECTS                        TO $GRANT_USER;
            GRANT ALL ON PG_CATALOG.ALL_OBJECTS             TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_OBJECTS             TO $GRANT_USER;
            GRANT ALL ON ALL_USERS                          TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_USERS                          TO $GRANT_USER;
            GRANT ALL ON ALL_SEQUENCES                      TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_SEQUENCES                      TO $GRANT_USER;
            GRANT ALL ON ALL_ALL_TABLES                     TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_ALL_TABLES                     TO $GRANT_USER;
            GRANT ALL ON ALL_TABLES                         TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_TABLES                     TO $GRANT_USER;
            GRANT ALL ON USER_OBJECTS                       TO $GRANT_USER;
            GRANT ALL ON SYS.USER_OBJECTS                   TO $GRANT_USER;
            GRANT ALL ON ALL_DIRECTORIES                    TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_DIRECTORIES                TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_DIRECTORIES                    TO $GRANT_USER;
            GRANT ALL ON ALL_SOURCE                         TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_SOURCE                     TO $GRANT_USER;
            GRANT ALL ON ALL_DEPENDENCIES                   TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_DEPENDENCIES               TO $GRANT_USER;
            GRANT ALL ON ALL_VIEWS                          TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_VIEWS                      TO $GRANT_USER;
            GRANT ALL ON ALL_PROCEDURES                     TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_PROCEDURES                 TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_TAB_COLUMNS                    TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_SOURCE                         TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_PROCEDURES                     TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_SEQUENCES                      TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_TRIGGERS                       TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_VIEWS                          TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_INDEXES                        TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_TABLES                         TO $GRANT_USER;
            GRANT ALL ON DBA_TABLES_2                       TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_TABLESPACES                    TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_USERS                          TO $GRANT_USER;
            GRANT ALL ON USER_TAB_COLUMNS                   TO $GRANT_USER;
            GRANT ALL ON SYS.USER_TAB_COLUMNS               TO $GRANT_USER;
            GRANT ALL ON USER_PROCEDURES                    TO $GRANT_USER;
            GRANT ALL ON SYS.USER_PROCEDURES                    TO $GRANT_USER;
            GRANT ALL ON USER_SOURCE                        TO $GRANT_USER;
            GRANT ALL ON SYS.USER_SOURCE                        TO $GRANT_USER;
            GRANT ALL ON USER_SEQUENCES                     TO $GRANT_USER;
            GRANT ALL ON SYS.USER_SEQUENCES                     TO $GRANT_USER;
            GRANT ALL ON USER_TABLES                        TO $GRANT_USER;
            GRANT ALL ON SYS.USER_TABLES                        TO $GRANT_USER;
            GRANT ALL ON USER_INDEXES                       TO $GRANT_USER;
            GRANT ALL ON SYS.USER_INDEXES                       TO $GRANT_USER;
            GRANT ALL ON USER_TRIGGERS                      TO $GRANT_USER;
            GRANT ALL ON SYS.USER_TRIGGERS                      TO $GRANT_USER;
            GRANT ALL ON USER_VIEWS                         TO $GRANT_USER;
            GRANT ALL ON SYS.USER_VIEWS                         TO $GRANT_USER;
            GRANT ALL ON information_schema.CONSTRAINT_TABLE_USAGE             TO $GRANT_USER;
            GRANT ALL ON information_schema.DOMAIN_CONSTRAINTS                 TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_DATA_FILES                     TO $GRANT_USER;
            GRANT ALL ON PG_AUTHID_VIEW                     TO $GRANT_USER;
            GRANT ALL ON SYS.USER_TABLESPACES                   TO $GRANT_USER;
            GRANT ALL ON PG_DATABASE_VIEW                   TO $GRANT_USER;
            GRANT ALL ON information_schema.DOMAIN_UDT_USAGE                   TO $GRANT_USER;
            GRANT ALL ON USER_TABLESPACES                   TO $GRANT_USER;
            GRANT ALL ON ALL_COL_COMMENTS                   TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_COL_COMMENTS                   TO $GRANT_USER;
            GRANT ALL ON ALL_TAB_COLUMNS                    TO $GRANT_USER;
            GRANT ALL ON SYS.ALL_TAB_COLUMNS                    TO $GRANT_USER;
            GRANT ALL ON USER_JOBS                          TO $GRANT_USER;
            GRANT ALL ON information_schema.CONSTRAINT_COLUMN_USAGE            TO $GRANT_USER;
            GRANT ALL ON SYS.USER_JOBS                          TO $GRANT_USER;
            GRANT ALL ON SYS.DBA_JOBS                           TO $GRANT_USER;
            GRANT ALL ON PG_ATTRIBUTE                       TO $GRANT_USER;
            GRANT ALL ON PG_JOB_VIEW                        TO $GRANT_USER;
            GRANT ALL ON PG_PROC                            TO $GRANT_USER;
            GRANT ALL ON PG_JOBOID_VIEW                     TO $GRANT_USER;
            GRANT ALL ON PG_JOB_PROC_VIEW                   TO $GRANT_USER;
            GRANT ALL ON PG_JOB_SCHEDULE_VIEW               TO $GRANT_USER;
            GRANT ALL ON PG_CLASS                           TO $GRANT_USER;
            GRANT ALL ON PG_DATABASE                        TO $GRANT_USER;
            GRANT ALL ON PG_CONSTRAINT                      TO $GRANT_USER;
            GRANT ALL ON PG_INHERITS                        TO $GRANT_USER;
            GRANT ALL ON PG_INDEX                           TO $GRANT_USER;
            GRANT ALL ON PG_OPERATOR                        TO $GRANT_USER;
            GRANT ALL ON PG_OPFAMILY                        TO $GRANT_USER;
            GRANT ALL ON PG_OPCLASS                         TO $GRANT_USER;
            GRANT ALL ON PG_AM                              TO $GRANT_USER;
            GRANT ALL ON PG_AMOP                            TO $GRANT_USER;
            GRANT ALL ON PG_AMPROC                          TO $GRANT_USER;
            GRANT ALL ON PG_LANGUAGE                        TO $GRANT_USER;
            GRANT ALL ON PG_LARGEOBJECT_METADATA            TO $GRANT_USER;
            GRANT ALL ON PG_AGGREGATE                       TO $GRANT_USER;
            GRANT ALL ON PG_REWRITE                         TO $GRANT_USER;
            GRANT ALL ON PG_TRIGGER                         TO $GRANT_USER;
            GRANT ALL ON PG_DESCRIPTION                     TO $GRANT_USER;
            GRANT ALL ON PG_CAST                            TO $GRANT_USER;
            GRANT ALL ON PG_ENUM                            TO $GRANT_USER;
            GRANT ALL ON PG_NAMESPACE                       TO $GRANT_USER;
            GRANT ALL ON PG_CONVERSION                      TO $GRANT_USER;
            GRANT ALL ON PG_DEPEND                          TO $GRANT_USER;
            GRANT ALL ON PG_DB_ROLE_SETTING                 TO $GRANT_USER;
            GRANT ALL ON PG_TABLESPACE                      TO $GRANT_USER;
            GRANT ALL ON PG_PLTEMPLATE                      TO $GRANT_USER;
            GRANT ALL ON PG_STATIO_USER_SEQUENCES           TO $GRANT_USER;
            GRANT ALL ON PG_STAT_ACTIVITY                   TO $GRANT_USER;
            GRANT ALL ON PG_STAT_REPLICATION                TO $GRANT_USER;
            GRANT ALL ON information_schema.INFORMATION_SCHEMA_CATALOG_NAME    TO $GRANT_USER;
            GRANT ALL ON information_schema.APPLICABLE_ROLES                   TO $GRANT_USER;
            GRANT ALL ON information_schema.ADMINISTRABLE_ROLE_AUTHORIZATIONS  TO $GRANT_USER;
            GRANT ALL ON information_schema.ATTRIBUTES                         TO $GRANT_USER;
            GRANT ALL ON information_schema.CHARACTER_SETS                     TO $GRANT_USER;
            GRANT ALL ON information_schema.CHECK_CONSTRAINT_ROUTINE_USAGE     TO $GRANT_USER;
            GRANT ALL ON information_schema.CHECK_CONSTRAINTS                  TO $GRANT_USER;
            GRANT ALL ON information_schema.COLLATIONS                         TO $GRANT_USER;
            GRANT ALL ON information_schema.COLLATION_CHARACTER_SET_APPLICABILITY TO $GRANT_USER;
            GRANT ALL ON PG_SHDEPEND                        TO $GRANT_USER;
            GRANT ALL ON PG_SHDESCRIPTION                   TO $GRANT_USER;
            GRANT ALL ON PG_TS_CONFIG                       TO $GRANT_USER;
            GRANT ALL ON PG_TS_CONFIG_MAP                   TO $GRANT_USER;
            GRANT ALL ON PG_TS_DICT                         TO $GRANT_USER;
            GRANT ALL ON PG_TS_PREFERENCE                   TO $GRANT_USER;
            GRANT ALL ON PG_TS_GIN                          TO $GRANT_USER;
            GRANT ALL ON PG_TS_PARSER                       TO $GRANT_USER;
            GRANT ALL ON PG_TS_TEMPLATE                     TO $GRANT_USER;
            GRANT ALL ON PG_EXTENSION                       TO $GRANT_USER;
            GRANT ALL ON PG_FOREIGN_DATA_WRAPPER            TO $GRANT_USER;
            GRANT ALL ON PG_FOREIGN_SERVER                  TO $GRANT_USER;
            GRANT ALL ON PG_DEFAULT_ACL                     TO $GRANT_USER;
            GRANT ALL ON PG_SECLABEL                        TO $GRANT_USER;
            GRANT ALL ON PG_SHSECLABEL                      TO $GRANT_USER;
            GRANT ALL ON PG_COLLATION                       TO $GRANT_USER;
            GRANT ALL ON PG_RANGE                           TO $GRANT_USER;
            GRANT ALL ON PG_PARTDEF                         TO $GRANT_USER;
            GRANT ALL ON PG_PARTITION                       TO $GRANT_USER;
            GRANT ALL ON PG_JOB                             TO $GRANT_USER;
            GRANT ALL ON PG_JOB_PROC                        TO $GRANT_USER;
            GRANT ALL ON PG_JOB_SCHEDULE                    TO $GRANT_USER;
            GRANT ALL ON PG_DIRECTORY                       TO $GRANT_USER;
            GRANT ALL ON information_schema.COLUMN_DOMAIN_USAGE                TO $GRANT_USER;
            GRANT ALL ON information_schema.COLUMN_PRIVILEGES                  TO $GRANT_USER;
            GRANT ALL ON information_schema.COLUMN_UDT_USAGE                   TO $GRANT_USER;
            GRANT ALL ON information_schema.COLUMNS                            TO $GRANT_USER;
            GRANT ALL ON information_schema.DOMAINS                            TO $GRANT_USER;
            GRANT ALL ON information_schema.ENABLED_ROLES                      TO $GRANT_USER;
            GRANT ALL ON information_schema.KEY_COLUMN_USAGE                   TO $GRANT_USER;
            GRANT ALL ON information_schema.PARAMETERS                         TO $GRANT_USER;
            GRANT ALL ON information_schema.REFERENTIAL_CONSTRAINTS            TO $GRANT_USER;
            GRANT ALL ON information_schema.ROLE_COLUMN_GRANTS                 TO $GRANT_USER;
            GRANT ALL ON information_schema.ROUTINE_PRIVILEGES                 TO $GRANT_USER;
            GRANT ALL ON information_schema.ROLE_ROUTINE_GRANTS                TO $GRANT_USER;
            GRANT ALL ON information_schema.ROUTINES                           TO $GRANT_USER;
            GRANT ALL ON information_schema.SCHEMATA                           TO $GRANT_USER;
            GRANT ALL ON information_schema.SEQUENCES                          TO $GRANT_USER;
            GRANT ALL ON information_schema.TABLE_CONSTRAINTS                  TO $GRANT_USER;
            GRANT ALL ON information_schema.TABLE_PRIVILEGES                   TO $GRANT_USER;
            GRANT ALL ON information_schema.ROLE_TABLE_GRANTS                  TO $GRANT_USER;
            GRANT ALL ON information_schema.TABLES                             TO $GRANT_USER;
            GRANT ALL ON information_schema.SQL_IMPLEMENTATION_INFO            TO $GRANT_USER;
            GRANT ALL ON information_schema.SQL_LANGUAGES                      TO $GRANT_USER;
            GRANT ALL ON information_schema.SQL_PACKAGES                       TO $GRANT_USER;
            GRANT ALL ON information_schema.SQL_SIZING                         TO $GRANT_USER;
            GRANT ALL ON information_schema.SQL_SIZING_PROFILES                TO $GRANT_USER;
            GRANT ALL ON information_schema.TRIGGERED_UPDATE_COLUMNS           TO $GRANT_USER;
            GRANT ALL ON information_schema.TRIGGERS                           TO $GRANT_USER;
            GRANT ALL ON information_schema.UDT_PRIVILEGES                     TO $GRANT_USER;
            GRANT ALL ON information_schema.ROLE_UDT_GRANTS                    TO $GRANT_USER;
            GRANT ALL ON information_schema.USAGE_PRIVILEGES                   TO $GRANT_USER;
            GRANT ALL ON information_schema.ROLE_USAGE_GRANTS                  TO $GRANT_USER;
            GRANT ALL ON information_schema.USER_DEFINED_TYPES                 TO $GRANT_USER;
            GRANT ALL ON information_schema.VIEW_COLUMN_USAGE                  TO $GRANT_USER;
            GRANT ALL ON information_schema.VIEW_ROUTINE_USAGE                 TO $GRANT_USER;
            GRANT ALL ON information_schema.VIEW_TABLE_USAGE                   TO $GRANT_USER;
            GRANT ALL ON information_schema.VIEWS                              TO $GRANT_USER;
            GRANT ALL ON information_schema.DATA_TYPE_PRIVILEGES               TO $GRANT_USER;
            GRANT ALL ON information_schema.ELEMENT_TYPES                      TO $GRANT_USER;
            GRANT ALL ON information_schema.COLUMN_OPTIONS                     TO $GRANT_USER;
            GRANT ALL ON information_schema.FOREIGN_DATA_WRAPPER_OPTIONS       TO $GRANT_USER;
            GRANT ALL ON information_schema.FOREIGN_DATA_WRAPPERS              TO $GRANT_USER;
            GRANT ALL ON information_schema.FOREIGN_SERVER_OPTIONS             TO $GRANT_USER;
            GRANT ALL ON information_schema.FOREIGN_SERVERS                    TO $GRANT_USER;
            GRANT ALL ON information_schema.FOREIGN_TABLE_OPTIONS              TO $GRANT_USER;
            GRANT ALL ON information_schema.FOREIGN_TABLES                     TO $GRANT_USER;
            GRANT ALL ON information_schema.USER_MAPPING_OPTIONS               TO $GRANT_USER;
            GRANT ALL ON information_schema.USER_MAPPINGS                      TO $GRANT_USER;
            GRANT ALL ON PG_ATTRDEF                         TO $GRANT_USER;
            GRANT ALL ON PG_AUTH_MEMBERS                    TO $GRANT_USER;
            GRANT ALL ON information_schema.SQL_FEATURES                       TO $GRANT_USER;
XXXEOFXXX" 2>&1
}

DB_USER=$2
DB_NAME=$1

right_recovery

create login crm_login with password='chinapay'

use CPDataWarehouse;
go
create user crm_login for login crm_login;
go

grant select on Table_FeeCalcResult to crm_login;
grant select on FactDailyTrans to crm_login;
grant select on Table_OraTransSum to crm_login;
grant select on Table_WUTransLog to crm_login;
grant select on Table_UpopliqFeeLiqResult to crm_login;
grant select on Table_TrfTransLog to crm_login;
grant select on Table_UpopliqMerInfo to crm_login;

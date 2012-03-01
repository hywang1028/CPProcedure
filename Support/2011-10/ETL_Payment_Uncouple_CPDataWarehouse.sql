
--**Backup CPDataWarehouse
use CPDataWarehouse

--1.
drop table Incoming_IncreasedGateBank

drop table DimGate;

--2.
drop table Incoming_IncreasedMerchantGroup;

drop table DimMerchant;

--3.
drop table dbo.Incoming_IncreasedBranchChannel

drop table dbo.DimBranchChannel

drop table dbo.FactBranchChannel

--4.
alter table FactDailyTrans
drop constraint PK_FACTDAILYTRANS;

alter table FactDailyTrans
drop column GateID,MerchantID;

alter table FactDailyTrans
add constraint PK_FACTDAILYTRANS primary key(DailyTransDate,MerchantNo,GateNo);

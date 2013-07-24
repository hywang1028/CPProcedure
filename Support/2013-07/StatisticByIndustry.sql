
create table #DateRange
(
	startdate date,
	enddate date
);

insert into #DateRange
(
	startdate,
	enddate
)
values
(
	'2012-07-01',
	'2013-01-01'
);
	
--1. 代付
select
	CPDate as TransDate,
	MerchantNo as Mer,
	BankSettingID as Bank,
	TransAmount as TransAmt,
	N'Ora' as Category
into
	#Ora
from
	Table_OraTransSum
where
	CPDate >= (select startdate from #DateRange)
	and
	CPDate < (select enddate from #DateRange)
union all
select
	CPDate as TransDate,
	MerchantNo as Mer,
	ChannelNo as Bank,
	SucceedAmt as TransAmt,
	N'Ora' as Category
from
	Table_TraScreenSum
where
	CPDate >= (select startdate from #DateRange)
	and
	CPDate < (select enddate from #DateRange)
	and
	TransType in ('100002', '100005');
	
--2. 新代扣
select
	CPDate as TransDate,
	MerchantNo as Mer,
	ChannelNo as Bank,
	SucceedAmt as TransAmt,
	N'Withhold' as Category
into
	#Withhold
from
	Table_TraScreenSum
where
	CPDate >= (select startdate from #DateRange)
	and
	CPDate < (select enddate from #DateRange)
	and
	TransType in ('100001', '100004');

--select
--	SUM(TransAmt)/100.0 as Amt
--from
--	#Withhold;	

--3. FactDailyTrans
select
	DailyTransDate as TransDate,
	MerchantNo as Mer,
	GateNo as Bank,
	SucceedTransAmount as TransAmt,
	convert(nvarchar(20), N'') as Category
into
	#FactDailyTrans
from
	FactDailyTrans
where
	DailyTransDate >= (select startdate from #DateRange)
	and
	DailyTransDate < (select enddate from #DateRange);
	
--3.1 金额转化为人民币
With CuryCodeRate as
(
	select
		CuryCode,
		AVG(CuryRate) as CuryRate
	from
		Table_CuryFullRate
	where
		CuryDate >= (select startdate from #DateRange)
		and
		CuryDate < (select enddate from #DateRange)
	group by
		CuryCode
)
update
	Fact
set
	Fact.TransAmt = Fact.TransAmt*Cury.CuryRate
from
	#FactDailyTrans Fact
	inner join
	Table_MerInfoExt Ext
	on
		Fact.Mer = Ext.MerchantNo
	inner join
	CuryCodeRate Cury
	on
		Ext.CuryCode = Cury.CuryCode;

--update
--	Trans
--set
--	Trans.Category = N''
--from
--	#FactDailyTrans Trans

--3.2 老代扣
update
	Trans
set
	Trans.Category = N'Withhold'
from
	#FactDailyTrans Trans
where
	Trans.Bank in ('7002','7008')
	and
	Trans.Category = N'';
	
--3.3 B2B
update
	Trans
set
	Trans.Category = N'B2B'
from
	#FactDailyTrans Trans
where
	Trans.Bank in (select GateNo from Table_GateCategory where GateCategory1 = N'B2B')
	and
	Trans.Category = N'';
	
--3.4 Indirect UPOP
update
	Trans
set
	Trans.Category = N'IndUPOP'
from
	#FactDailyTrans Trans
where
	Trans.Bank in (select GateNo from Table_GateCategory where GateCategory1 = N'UPOP')
	and
	Trans.Category = N'';
	
--3.5 EPOS
update
	Trans
set
	Trans.Category = N'EPOS'
from
	#FactDailyTrans Trans
where
	Trans.Bank in ('0018','0019','8018')
	and
	Trans.Mer not in (select MerchantNo from Table_EposTakeoffMerchant)
	and
	Trans.Category = N'';
	
--3.6 ForeignB2C
update
	Trans
set
	Trans.Category = N'ForeignB2C'
from
	#FactDailyTrans Trans
where
	Trans.Mer in (select MerchantNo from Table_MerInfoExt)
	and
	Trans.Category = N'';
	
--3.7 DomesticB2C
update
	Trans
set
	Trans.Category = N'DomesticB2C'
from
	#FactDailyTrans Trans
where
	Trans.Category = N'';
	
--4. DirectUPOP
select
	Upopliq.TransDate,
	isnull((select CpMerNo from Table_CpUpopRelation where UpopMerNo = Upopliq.MerchantNo),Upopliq.MerchantNo) as Mer,
	Upopliq.GateNo as Bank,
	Upopliq.PurAmt as TransAmt,
	N'DirectUPOP' as Category
into
	#DirectUPOP
from
	Table_UpopliqFeeLiqResult Upopliq
where
	Upopliq.TransDate >= (select startdate from #DateRange)
	and
	Upopliq.TransDate < (select enddate from #DateRange);


--5. integrate all data
With AllData as
(
	select
		TransDate,
		Mer,
		Bank,
		TransAmt,
		Category
	from
		#Ora
	union all
	select
		TransDate,
		Mer,
		Bank,
		TransAmt,
		Category
	from
		#Withhold
	union all
	select
		TransDate,
		Mer,
		Bank,
		TransAmt,
		Category
	from
		#FactDailyTrans
	union all
	select
		TransDate,
		Mer,
		Bank,
		TransAmt,
		Category
	from
		#DirectUPOP
	
)
select
	a.Mer,
	SUM(case when a.Category = N'DomesticB2C' then a.TransAmt else 0 end) as DomesticB2C,
	SUM(case when a.Category = N'ForeignB2C' then a.TransAmt else 0 end) as ForeignB2C,
	SUM(case when a.Category = N'EPOS' then a.TransAmt else 0 end) as EPOS,
	SUM(case when a.Category = N'DirectUPOP' then a.TransAmt else 0 end) as DirectUPOP,
	SUM(case when a.Category = N'IndUPOP' then a.TransAmt else 0 end) as IndUPOP,
	SUM(case when a.Category = N'B2B' then a.TransAmt else 0 end) as B2B,
	SUM(case when a.Category = N'Withhold' then a.TransAmt else 0 end) as Withhold,
	SUM(case when a.Category = N'Ora' then a.TransAmt else 0 end) as Ora
into
	#AllData
from
	AllData a
group by
	a.Mer;

select 
	IndustryName
into
	#IndustryName
from
	Table_FinancialDeptConfiguration
union
select
	IndustryName
from
	Table_MerAttribute;

With AllDataWithIndustry as
(
	select
		a.Mer,
		coalesce(fin.IndustryName, sal.IndustryName, N'其它') as Industry,
		a.DomesticB2C,
		a.ForeignB2C,
		a.EPOS,
		a.DirectUPOP,
		a.IndUPOP,
		a.B2B,
		a.Withhold,
		a.Ora
	from
		#AllData a
		left join
		Table_FinancialDeptConfiguration fin
		on
			a.Mer = fin.MerchantNo
		left join
		Table_MerAttribute sal
		on
			a.Mer = sal.MerchantNo
),
FormatResult as
(
	select
		Industry,
		SUM(a.DomesticB2C)/10000000000.0 as DomesticB2C,
		SUM(a.ForeignB2C)/10000000000.0 as ForeignB2C,
		SUM(a.EPOS)/10000000000.0 as EPOS,
		SUM(a.DirectUPOP)/10000000000.0 as DirectUPOP,
		SUM(a.IndUPOP)/10000000000.0 as IndUPOP,
		SUM(a.B2B)/10000000000.0 as B2B,
		SUM(a.Withhold)/10000000000.0 as Withhold,
		SUM(a.Ora)/10000000000.0 as Ora
	from
		AllDataWithIndustry a
	group by
		a.Industry
)
select
	isnull(i.IndustryName, r.Industry) as Industry,
	isnull(r.DomesticB2C, 0) as DomesticB2C,
	isnull(r.ForeignB2C, 0) as ForeignB2C,
	isnull(r.EPOS, 0) as EPOS,
	isnull(r.DirectUPOP, 0) as DirectUPOP,
	isnull(r.IndUPOP, 0) as IndUPOP,
	isnull(r.B2B, 0) as B2B,
	isnull(r.Withhold, 0) as Withhold,
	isnull(r.Ora, 0) as Ora
from
	#IndustryName i
	full outer join
	FormatResult r
	on
		i.IndustryName = r.Industry	

		


	
drop table #Ora;
drop table #Withhold;
drop table #DateRange;
drop table #FactDailyTrans;
drop table #DirectUPOP;
drop table #AllData;
drop table #IndustryName;

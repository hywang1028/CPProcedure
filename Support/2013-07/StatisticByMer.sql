
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
	'2013-01-01',
	'2013-07-01'
);
	
--1. 代付
select
	CPDate as TransDate,
	MerchantNo as Mer,
	BankSettingID as Bank,
	TransCount as TransCnt,
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
	SucceedCnt as TransCnt,
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
	SucceedCnt as TransCnt,
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
	SucceedTransCount as TransCnt,
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
	Upopliq.MerchantNo as Mer,
	Upopliq.GateNo as Bank,
	Upopliq.PurCnt as TransCnt,
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
		TransCnt,
		TransAmt,
		Category
	from
		#Ora
	union all
	select
		TransDate,
		Mer,
		Bank,
		TransCnt,
		TransAmt,
		Category
	from
		#Withhold
	union all
	select
		TransDate,
		Mer,
		Bank,
		TransCnt,
		TransAmt,
		Category
	from
		#FactDailyTrans
	union all
	select
		TransDate,
		Mer,
		Bank,
		TransCnt,
		TransAmt,
		Category
	from
		#DirectUPOP
	
)
select
	a.Mer,
	
	SUM(case when a.Category = N'DomesticB2C' then a.TransCnt else 0 end)/10000.0 as DomesticB2C_Cnt,
	SUM(case when a.Category = N'ForeignB2C' then a.TransCnt else 0 end)/10000.0 as ForeignB2C_Cnt,
	SUM(case when a.Category = N'EPOS' then a.TransCnt else 0 end)/10000.0 as EPOS_Cnt,
	SUM(case when a.Category = N'DirectUPOP' then a.TransCnt else 0 end)/10000.0 as DirUPOP_Cnt,
	SUM(case when a.Category = N'IndUPOP' then a.TransCnt else 0 end)/10000.0 as IndUPOP_Cnt,
	SUM(case when a.Category = N'B2B' then a.TransCnt else 0 end)/10000.0 as B2B_Cnt,
	SUM(case when a.Category = N'Withhold' then a.TransCnt else 0 end)/10000.0 as Withhold_Cnt,
	SUM(case when a.Category = N'Ora' then a.TransCnt else 0 end)/10000.0 as Ora_Cnt,
	
	SUM(case when a.Category = N'DomesticB2C' then a.TransAmt else 0 end)/1000000.0 as DomesticB2C_Amt,
	SUM(case when a.Category = N'ForeignB2C' then a.TransAmt else 0 end)/1000000.0 as ForeignB2C_Amt,
	SUM(case when a.Category = N'EPOS' then a.TransAmt else 0 end)/1000000.0 as EPOS_Amt,
	SUM(case when a.Category = N'DirectUPOP' then a.TransAmt else 0 end)/1000000.0 as DirUPOP_Amt,
	SUM(case when a.Category = N'IndUPOP' then a.TransAmt else 0 end)/1000000.0 as IndUPOP_Amt,
	SUM(case when a.Category = N'B2B' then a.TransAmt else 0 end)/1000000.0 as B2B_Amt,
	SUM(case when a.Category = N'Withhold' then a.TransAmt else 0 end)/1000000.0 as Withhold_Amt,
	SUM(case when a.Category = N'Ora' then a.TransAmt else 0 end)/1000000.0 as Ora_Amt
into
	#AllData2013_FirstHalf
from
	AllData a
group by
	a.Mer;

		


	
drop table #Ora;
drop table #Withhold;
drop table #DateRange;
drop table #FactDailyTrans;
drop table #DirectUPOP;



select * from #AllData2013_FirstHalf;
select * from #AllData2012_FirstHalf;
select * from #AllData2012_SecondHalf;

select
	coalesce(a.Mer, b.Mer) as Mer,
	coalesce((select MerchantName from Table_MerInfo where MerchantNo = coalesce(a.Mer, b.Mer)),
			 (select MerchantName from Table_OraMerchants where MerchantNo = coalesce(a.Mer, b.Mer)),
			 (select MerchantName from Table_TraMerchantInfo where MerchantNo = coalesce(a.Mer, b.Mer)),
			 (select MerchantName from Table_UpopliqMerInfo where MerchantNo = coalesce(a.Mer, b.Mer))) as MerchantName,
--2013年上半年	
	isnull(a.DomesticB2C_Cnt, 0) as DomesticB2C_Cnt,
	isnull(a.ForeignB2C_Cnt, 0) as ForeignB2C_Cnt,
	isnull(a.EPOS_Cnt, 0) as EPOS_Cnt,
	isnull(a.DirUPOP_Cnt, 0) as DirUPOP_Cnt,
	isnull(a.IndUPOP_Cnt, 0) as IndUPOP_Cnt,
	isnull(a.B2B_Cnt, 0) as B2B_Cnt,
	isnull(a.Withhold_Cnt, 0) as Withhold_Cnt,
	isnull(a.Ora_Cnt, 0) as Ora_Cnt,
	
	isnull(a.DomesticB2C_Amt, 0) as DomesticB2C_Amt,
	isnull(a.ForeignB2C_Amt, 0) as ForeignB2C_Amt,
	isnull(a.EPOS_Amt, 0) as EPOS_Amt,
	isnull(a.DirUPOP_Amt, 0) as DirUPOP_Amt,
	isnull(a.IndUPOP_Amt, 0) as IndUPOP_Amt,
	isnull(a.B2B_Amt, 0) as B2B_Amt,
	isnull(a.Withhold_Amt, 0) as Withhold_Amt,
	isnull(a.Ora_Amt, 0) as Ora_Amt,

	N'|' as Sep,
--2012年上半年	
	isnull(b.DomesticB2C_Cnt, 0) as DomesticB2C_Cnt,
	isnull(b.ForeignB2C_Cnt, 0) as ForeignB2C_Cnt,
	isnull(b.EPOS_Cnt, 0) as EPOS_Cnt,
	isnull(b.DirUPOP_Cnt, 0) as DirUPOP_Cnt,
	isnull(b.IndUPOP_Cnt, 0) as IndUPOP_Cnt,
	isnull(b.B2B_Cnt, 0) as B2B_Cnt,
	isnull(b.Withhold_Cnt, 0) as Withhold_Cnt,
	isnull(b.Ora_Cnt, 0) as Ora_Cnt,
	
	isnull(b.DomesticB2C_Amt, 0) as DomesticB2C_Amt,
	isnull(b.ForeignB2C_Amt, 0) as ForeignB2C_Amt,
	isnull(b.EPOS_Amt, 0) as EPOS_Amt,
	isnull(b.DirUPOP_Amt, 0) as DirUPOP_Amt,
	isnull(b.IndUPOP_Amt, 0) as IndUPOP_Amt,
	isnull(b.B2B_Amt, 0) as B2B_Amt,
	isnull(b.Withhold_Amt, 0) as Withhold_Amt,
	isnull(b.Ora_Amt, 0) as Ora_Amt,
	
	N'|' as Sep,
--差额
	isnull(a.DomesticB2C_Cnt, 0) - isnull(b.DomesticB2C_Cnt, 0) as DomesticB2C_Cnt,
	isnull(a.ForeignB2C_Cnt, 0) - isnull(b.ForeignB2C_Cnt, 0) as ForeignB2C_Cnt,
	isnull(a.EPOS_Cnt, 0) - isnull(b.EPOS_Amt, 0) as EPOS_Cnt,
	isnull(a.DirUPOP_Cnt, 0) - isnull(b.DirUPOP_Cnt, 0) as DirUPOP_Cnt,
	isnull(a.IndUPOP_Cnt, 0) - isnull(b.IndUPOP_Cnt, 0) as IndUPOP_Cnt,
	isnull(a.B2B_Cnt, 0) - isnull(b.B2B_Cnt, 0) as B2B_Cnt,
	isnull(a.Withhold_Cnt, 0) - isnull(b.Withhold_Cnt, 0) as Withhold_Cnt,
	isnull(a.Ora_Cnt, 0) - isnull(b.Ora_Cnt, 0) as Ora_Cnt,
	
	isnull(a.DomesticB2C_Amt, 0) - isnull(b.DomesticB2C_Amt, 0) as DomesticB2C_Amt,
	isnull(a.ForeignB2C_Amt, 0) - isnull(b.ForeignB2C_Amt, 0) as ForeignB2C_Amt,
	isnull(a.EPOS_Amt, 0) - isnull(b.EPOS_Amt, 0) as EPOS_Amt,
	isnull(a.DirUPOP_Amt, 0) - isnull(b.DirUPOP_Amt, 0) as DirUPOP_Amt,
	isnull(a.IndUPOP_Amt, 0) - isnull(b.IndUPOP_Amt, 0) as IndUPOP_Amt,
	isnull(a.B2B_Amt, 0) - isnull(b.B2B_Amt, 0) as B2B_Amt,
	isnull(a.Withhold_Amt, 0) - isnull(b.Withhold_Amt, 0) as Withhold_Amt,
	isnull(a.Ora_Amt, 0) - isnull(b.Ora_Amt, 0) as Ora_Amt
from
	#AllData2013_FirstHalf a
	full outer join
	#AllData2012_FirstHalf b
	on
		a.Mer = b.Mer;




select
	coalesce(a.Mer, b.Mer) as Mer,
	coalesce((select MerchantName from Table_MerInfo where MerchantNo = coalesce(a.Mer, b.Mer)),
			 (select MerchantName from Table_OraMerchants where MerchantNo = coalesce(a.Mer, b.Mer)),
			 (select MerchantName from Table_TraMerchantInfo where MerchantNo = coalesce(a.Mer, b.Mer)),
			 (select MerchantName from Table_UpopliqMerInfo where MerchantNo = coalesce(a.Mer, b.Mer))) as MerchantName,
--2013年上半年	
	isnull(a.DomesticB2C_Cnt, 0) as DomesticB2C_Cnt,
	isnull(a.ForeignB2C_Cnt, 0) as ForeignB2C_Cnt,
	isnull(a.EPOS_Cnt, 0) as EPOS_Cnt,
	isnull(a.DirUPOP_Cnt, 0) as DirUPOP_Cnt,
	isnull(a.IndUPOP_Cnt, 0) as IndUPOP_Cnt,
	isnull(a.B2B_Cnt, 0) as B2B_Cnt,
	isnull(a.Withhold_Cnt, 0) as Withhold_Cnt,
	isnull(a.Ora_Cnt, 0) as Ora_Cnt,
	
	isnull(a.DomesticB2C_Amt, 0) as DomesticB2C_Amt,
	isnull(a.ForeignB2C_Amt, 0) as ForeignB2C_Amt,
	isnull(a.EPOS_Amt, 0) as EPOS_Amt,
	isnull(a.DirUPOP_Amt, 0) as DirUPOP_Amt,
	isnull(a.IndUPOP_Amt, 0) as IndUPOP_Amt,
	isnull(a.B2B_Amt, 0) as B2B_Amt,
	isnull(a.Withhold_Amt, 0) as Withhold_Amt,
	isnull(a.Ora_Amt, 0) as Ora_Amt,

	N'|' as Sep,
--2012年下半年	
	isnull(b.DomesticB2C_Cnt, 0) as DomesticB2C_Cnt,
	isnull(b.ForeignB2C_Cnt, 0) as ForeignB2C_Cnt,
	isnull(b.EPOS_Cnt, 0) as EPOS_Cnt,
	isnull(b.DirUPOP_Cnt, 0) as DirUPOP_Cnt,
	isnull(b.IndUPOP_Cnt, 0) as IndUPOP_Cnt,
	isnull(b.B2B_Cnt, 0) as B2B_Cnt,
	isnull(b.Withhold_Cnt, 0) as Withhold_Cnt,
	isnull(b.Ora_Cnt, 0) as Ora_Cnt,
	
	isnull(b.DomesticB2C_Amt, 0) as DomesticB2C_Amt,
	isnull(b.ForeignB2C_Amt, 0) as ForeignB2C_Amt,
	isnull(b.EPOS_Amt, 0) as EPOS_Amt,
	isnull(b.DirUPOP_Amt, 0) as DirUPOP_Amt,
	isnull(b.IndUPOP_Amt, 0) as IndUPOP_Amt,
	isnull(b.B2B_Amt, 0) as B2B_Amt,
	isnull(b.Withhold_Amt, 0) as Withhold_Amt,
	isnull(b.Ora_Amt, 0) as Ora_Amt,
	
	N'|' as Sep,
--差额
	isnull(a.DomesticB2C_Cnt, 0) - isnull(b.DomesticB2C_Cnt, 0) as DomesticB2C_Cnt,
	isnull(a.ForeignB2C_Cnt, 0) - isnull(b.ForeignB2C_Cnt, 0) as ForeignB2C_Cnt,
	isnull(a.EPOS_Cnt, 0) - isnull(b.EPOS_Amt, 0) as EPOS_Cnt,
	isnull(a.DirUPOP_Cnt, 0) - isnull(b.DirUPOP_Cnt, 0) as DirUPOP_Cnt,
	isnull(a.IndUPOP_Cnt, 0) - isnull(b.IndUPOP_Cnt, 0) as IndUPOP_Cnt,
	isnull(a.B2B_Cnt, 0) - isnull(b.B2B_Cnt, 0) as B2B_Cnt,
	isnull(a.Withhold_Cnt, 0) - isnull(b.Withhold_Cnt, 0) as Withhold_Cnt,
	isnull(a.Ora_Cnt, 0) - isnull(b.Ora_Cnt, 0) as Ora_Cnt,
	
	isnull(a.DomesticB2C_Amt, 0) - isnull(b.DomesticB2C_Amt, 0) as DomesticB2C_Amt,
	isnull(a.ForeignB2C_Amt, 0) - isnull(b.ForeignB2C_Amt, 0) as ForeignB2C_Amt,
	isnull(a.EPOS_Amt, 0) - isnull(b.EPOS_Amt, 0) as EPOS_Amt,
	isnull(a.DirUPOP_Amt, 0) - isnull(b.DirUPOP_Amt, 0) as DirUPOP_Amt,
	isnull(a.IndUPOP_Amt, 0) - isnull(b.IndUPOP_Amt, 0) as IndUPOP_Amt,
	isnull(a.B2B_Amt, 0) - isnull(b.B2B_Amt, 0) as B2B_Amt,
	isnull(a.Withhold_Amt, 0) - isnull(b.Withhold_Amt, 0) as Withhold_Amt,
	isnull(a.Ora_Amt, 0) - isnull(b.Ora_Amt, 0) as Ora_Amt
from
	#AllData2013_FirstHalf a
	full outer join
	#AllData2012_SecondHalf b
	on
		a.Mer = b.Mer;










drop table #AllData2013_FirstHalf;
drop table #AllData2012_FirstHalf;
drop table #AllData2012_SecondHalf;
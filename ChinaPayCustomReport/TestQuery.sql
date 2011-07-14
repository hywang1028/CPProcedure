
--1. Create BizCategory Table
Create Table #BizCategoryTable
(
	GroupName char(20),
	ItemID int,
	BizCategory char(20),
	GateCategory1 char(40)
);
insert into #BizCategoryTable(GroupName,ItemID,BizCategory,GateCategory1) values
(N'通道型交易',1,N'直连网关(B2C)',N'B2C'),
(N'通道型交易',2,N'企业网银(B2B)',N'B2B'),
(N'通道型交易',3,N'CUPSecure网关',N'CUPSecure'),
(N'通道型交易',4,N'UPOP网关',N'UPOP'),
(N'通道型交易',5,N'外卡网关',N'外卡'),
(N'通道型交易',6,N'预付费卡网关',N''),
(N'通道型交易',7,N'信用卡MOTO网关',N'MOTO'),
(N'通道型交易',8,N'借记卡IVR网关',N''),
(N'自有账户交易',9,N'御航宝交易',N'御航宝'),
(N'自主结算交易',10,N'代收代扣',N'代扣'),
(N'自主结算交易',11,N'代发代付',N'ORA'),
(N'自主结算交易',12,N'分账结算',N''),
(N'自主结算交易',13,N'互联宝',N'EPOS'),
(N'自主结算交易',14,N'B2B现金支付',N''),
(N'自主结算交易',15,N'信用卡还款',N''),
(N'自主结算交易',16,N'便民缴费',N'便民'),
(N'自主结算交易',17,N'自助终端账单',N''),
(N'自主结算交易',18,N'收单机构委托结算',N''),
(N'自主结算交易',19,N'境外汇款结算',N''),
(N'自主结算交易',20,N'境外收单结算',N''),
(N'非自主结算交易',21,N'银行卡跨行转账',N'转账'),
(N'非自主结算交易',22,N'基金直销交易',N'基金'),
(N'非自主结算交易',23,N'转接分公司交易',N'转接');

--2. Get the FactDailyTrans Data
--2.1 Filter FactDailyTrans Data
select
	GateCategory.GateCategory1,
	Trans.MerchantNo,
	Trans.SucceedTransAmount,
	Trans.SucceedTransCount
into
	#TransWithCategory
from
	dbo.Table_GateCategory GateCategory
	inner join
	dbo.FactDailyTrans Trans
	on
		GateCategory.GateNo = Trans.GateNo
where
	Trans.DailyTransDate >= '2011-04-01'
	and
	Trans.DailyTransDate < '2011-05-01'
	and
	GateCategory.GateCategory1 <> N'#N/A';

--2.2 The result take Off Merchant from EPOS
select
	TransWithCategory.GateCategory1,
	SUM(TransWithCategory.SucceedTransCount)
	- case when TransWithCategory.GateCategory1 = N'EPOS'
		then (select 
				 SUM(Trans2.SucceedTransCount)
			from 
				#TransWithCategory Trans2 
			where 
				Trans2.GateCategory1 = N'EPOS' 
				and 
				Trans2.MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
				)
		else 0
		end SucceedTransCount,
	SUM(TransWithCategory.SucceedTransAmount)
	- case when TransWithCategory.GateCategory1 = N'EPOS'
		then (select 
				 SUM(Trans2.SucceedTransAmount)
			from 
				#TransWithCategory Trans2 
			where 
				Trans2.GateCategory1 = N'EPOS' 
				and 
				Trans2.MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
				)
		else 0
		end SucceedTransAmount
into
	#GateCategoryAmount
from
	#TransWithCategory TransWithCategory
group by
	TransWithCategory.GateCategory1;

--2. Get the ORA Data
select
	N'ORA' as GateCategory1,
	SUM(TransAmount) SucceedTransAmount,
	SUM(TransCount) SucceedTransCount
into
	#ORATransAmount
from
	Table_OraTransSum
where
	CPDate >= '2011-04-01'
	and
	CPDate < '2011-05-01'
	
--3. Get Convenience Data
select
	N'便民' as GateCategory1,
	SUM(SucceedTransAmount) SucceedTransAmount,
	SUM(SucceedTransCount) SucceedTransCount
into
	#ConveTransAmount
from
	FactDailyTrans
where
	DailyTransDate >= '2011-04-01'
	and
	DailyTransDate < '2011-05-01'
	and
	MerchantNo in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001');
	
--4.Get Transfer Data
select
	N'转账' as GateCategory1,
	SUM(TransAmt) SucceedTransAmount,
	COUNT(TransAmt) SucceedTransCount
into
	#TransferAmount
from
	Table_TrfTransLog
where
	TransDate >= '2011-04-01'
	and
	TransDate < '2011-05-01'
	and
	TransType = '2070'
	
--5. Get Fund Data
select
	N'基金' as GateCategory1,
	SUM(TransAmt) SucceedTransAmount,
	COUNT(TransAmt) SucceedTransCount
into
	#FundTransAmount
from
	Table_TrfTransLog
where
	TransDate >= '2011-04-01'
	and
	TransDate < '2011-05-01'
	and
	TransType in ('3010','3020','3030','3040','3050')
	
--6. Get Switch Data
select
	N'转接' as GateCategory1,
	SUM(SucceedTransAmount) SucceedTransAmount,
	SUM(SucceedTransCount) SucceedTransCount
into
	#SwitchTransAmount
from
	FactDailyTrans
where
	DailyTransDate >= '2011-04-01'
	and
	DailyTransDate < '2011-05-01'
	and
	MerchantNo = '808080310004680';
	
select 
	BizCategoryTable.GroupName,
	BizCategoryTable.ItemID,
	BizCategoryTable.BizCategory,
	coalesce(GateCategoryAmount.SucceedTransAmount,ORATransAmount.SucceedTransAmount,ConveTransAmount.SucceedTransAmount,TransferAmount.SucceedTransAmount,FundTransAmount.SucceedTransAmount,SwitchTransAmount.SucceedTransAmount) SucceedTransAmount,
	coalesce(GateCategoryAmount.SucceedTransCount,ORATransAmount.SucceedTransCount,ConveTransAmount.SucceedTransCount,TransferAmount.SucceedTransCount,FundTransAmount.SucceedTransCount,SwitchTransAmount.SucceedTransCount) SucceedTransCount
from  
	#BizCategoryTable BizCategoryTable
	left join
	#GateCategoryAmount GateCategoryAmount
	on
		BizCategoryTable.GateCategory1 = GateCategoryAmount.GateCategory1
	left join
	#ORATransAmount ORATransAmount
	on
		BizCategoryTable.GateCategory1 = ORATransAmount.GateCategory1
	left join
	#ConveTransAmount ConveTransAmount
	on
		BizCategoryTable.GateCategory1 = ConveTransAmount.GateCategory1
	left join
	#TransferAmount TransferAmount
	on
		BizCategoryTable.GateCategory1 = TransferAmount.GateCategory1
	left join
	#FundTransAmount FundTransAmount
	on
		BizCategoryTable.GateCategory1 = FundTransAmount.GateCategory1
	left join
	#SwitchTransAmount SwitchTransAmount
	on
		BizCategoryTable.GateCategory1 = SwitchTransAmount.GateCategory1;
		
		
drop table #BizCategoryTable;
drop table #TransWithCategory;
drop table #GateCategoryAmount;
drop table #ORATransAmount;
drop table #ConveTransAmount;
drop table #TransferAmount;
drop table #FundTransAmount;
drop table #SwitchTransAmount;
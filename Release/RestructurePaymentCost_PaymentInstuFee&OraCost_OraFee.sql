--[Created] At 20120313 By 叶博：修改表Table_FeeCalcResult、Table_InstuMerRate、Table_OraBankCostRule结构，重构支付成本、收入、分润，ORA成本、收入存储过程
--更新计费结果表中所有金额的单位粒度到分
if exists(select top(1)
	*
from
	Table_FeeCalcResult
where
	ceiling(PurAmt) > PurAmt)
begin
	update 
		Table_FeeCalcResult
	set
		PurAmt = PurAmt * 100,
		RefAmt = RefAmt * 100,
		TransAmt = TransAmt * 100,
		FeeAmt = FeeAmt * 100,
		LiqAmt = LiqAmt * 100,
		InstuFeeAmt = InstuFeeAmt * 100,
		BankFeeAmt = BankFeeAmt * 100;
end


--修改支付收入规则表的表结构
--alter table
--	Table_PaymentMerRate
--drop constraint
--	DF__Table_Pay__RefMi__11BF94B6,
--	PK__Table_Pa__25FDF4C10FD74C44,
--	UQ__Table_Pa__90973C3A0CFADF99,
--	DF__Table_Pay__RefMa__12B3B8EF;
	
--alter table
--	Table_PaymentMerRate
--drop column
--	PaymentMerRateId;
	
--alter table
--	Table_PaymentMerRate
--alter column
--	RefMaxAmt bigint not null;
	
--alter table
--	Table_PaymentMerRate
--alter column
--	RefMinAmt bigint not null;	

--alter table
--	Table_PaymentMerRate
--add 
--	StartDate datetime not null default '1900-01-01',
--	EndDate datetime not null default '2200-01-01';

--alter table
--	Table_PaymentMerRate
--add constraint DF_Table_PayMerRate_RefMin
--	default (0)
--for
--	RefMinAmt;

--alter table
--	Table_PaymentMerRate
--add constraint DF_Table_PayMerRate_RefMax
--	default (100000000000000)
--for
--	RefMaxAmt;

--alter table
--	Table_PaymentMerRate
--add constraint 
--	PK_Table_PaymentMerRate primary key(MerchantNo,GateNo,FeeType,RefMinAmt,RefMaxAmt,StartDate);
	

--update
--	Table_PaymentMerRate
--set
--	RefMaxAmt = 100000000000000
--where	
--	RefMaxAmt = 1000000000000;

	
--select * from Table_PaymentMerRate where MerchantNo = '808080580004957' and GateNo = '8005';
	
	
--修改支付分润规则表的表结构
if OBJECT_ID(N'PK_Table_InstuMerRate', N'PK') is null
begin
	alter table
		Table_InstuMerRate
	drop constraint 
		PK__Table_In__E58BB8BE2E5BD364,
		UQ__Table_In__3D1662422B7F66B9;

	alter table
		Table_InstuMerRate
	drop column
		InstuMerRateId;
		
	alter table
		Table_InstuMerRate
	add 
		StartDate datetime not null default '1900-01-01',
		EndDate datetime not null default '2200-01-01';
		
	alter table
		Table_InstuMerRate
	add constraint
		PK_Table_InstuMerRate primary key (MerchantNo,GateNo,StartDate);
end

	
--修改ORA银行成本规则表结构
--if OBJECT_ID(N'PK_Table_OraBankCostRule', N'PK') is null
--begin
--	update	
--		Table_OraBankCostRule
--	set 
--		ApplyEndDate = '2200-01-01'
--	where
--		ApplyEndDate is null;

--	alter table
--		Table_OraBankCostRule
--	alter column
--		ApplyEndDate datetime not null;
		
--	alter table
--		Table_OraBankCostRule
--	drop constraint	
--		PK__Table_Or__8317040E575DE8F7,
--		UQ__Table_Or__EF1B84F254817C4C;

--	alter table
--		Table_OraBankCostRule
--	drop column
--		BankCostRuleID;

--	alter table
--		Table_OraBankCostRule
--	add constraint 
--		PK_Table_OraBankCostRule primary key(BankSettingID,ApplyStartDate);
--end

--drop table Table_OraBankCostRule
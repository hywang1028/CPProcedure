if OBJECT_ID(N'PK_Table_PaymentMerRate',N'PK')is null
begin
alter table
	Table_PaymentMerRate
drop constraint
	DF__Table_Pay__RefMa__12B3B8EF,
	DF__Table_Pay__RefMi__11BF94B6,
	PK__Table_Pa__25FDF4C10FD74C44,
	UQ__Table_Pa__90973C3A0CFADF99;
	
alter table
	Table_PaymentMerRate
drop column
	PaymentMerRateId;
	
alter table
	Table_PaymentMerRate
alter column
	RefMinAmt decimal(20,2) not null;		
	
alter table
	Table_PaymentMerRate
alter column
	RefMaxAmt decimal(20,2) not null;
	
alter table
	Table_PaymentMerRate
add constraint DF_Table_PayMerRate_RefMin
	default (0)
for
	RefMinAmt;

alter table
	Table_PaymentMerRate
add constraint DF_Table_PayMerRate_RefMax
	default (100000000000000)
for
	RefMaxAmt;

update
	Table_PaymentMerRate
set
	RefMaxAmt = 100000000000000
where	
	RefMaxAmt = 1000000000000;
	
alter table
	Table_PaymentMerRate
add 
	StartDate datetime not null default '1900-01-01',
	EndDate datetime not null default '2200-01-01';
	
alter table
	Table_PaymentMerRate
add constraint 
	PK_Table_PaymentMerRate primary key(MerchantNo,GateNo,FeeType,RefMinAmt,StartDate);

end
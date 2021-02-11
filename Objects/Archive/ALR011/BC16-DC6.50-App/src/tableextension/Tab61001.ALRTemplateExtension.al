tableextension 61001 "ALR Template Extension" extends "CDC Template"
{
    fields
    {
        field(61000; "Original Line Capt. Codeunit"; Integer)
        {
            Caption = 'Original Codeunit for Line Capturing';
            DataClassification = CustomerContent;
            TableRelation = AllObj."Object ID" where("Object Type" = filter(Codeunit));
        }
    }
}


enum 61001 "ALR Empty Field Value Handling"
{
    Extensible = true;
    value(0; Ignore)
    {
        Caption = 'Ignore';
    }
    value(1; DeleteLine)
    {
        Caption = 'Delete line';
    }
    value(2; CopyPrevLineValue)
    {
        Caption = 'Copy previous line field value';
    }
    value(3; CopyHeaderFieldValue)
    {
        Caption = 'Copy header field value';
    }
    value(4; CopyLineFieldValue)
    {
        Caption = 'Copy line field value';
    }
    value(5; FixedValue)
    {
        Caption = 'Fixed Value';
    }
}

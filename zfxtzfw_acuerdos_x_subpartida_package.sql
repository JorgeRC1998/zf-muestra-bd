create or replace package zfxtzfw_acuerdos_x_subpartida authid current_user
is
    procedure Insert$(
        iclbRecord                      in  clob,
        oclbXML                         out clob);
    procedure Update$(
        iclbRecord                      in  clob,
        oclbXML                         out clob);
    procedure Create$FromXMLLst(
        iclbParam                       in  clob,
        oclbXML                         out clob);
    procedure Delete$(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure XQuery(
        iclbParam                       in      clob,
        oclbXML                         out     clob);

end zfxtzfw_acuerdos_x_subpartida;
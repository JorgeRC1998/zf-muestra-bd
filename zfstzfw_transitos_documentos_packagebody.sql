create or replace PACKAGE BODY         "ZFSTZFW_TRANSITOS_DOCUMENTOS" 
is
/****************************************************************************************

    NOMBRE:       zfstzfw_transitos_documentos   
    PROPOSITO:    Manejar todas las operaciones de la tabla TZFW_DOCUMENTOS_X_CIA
                  Estado Corte.
    REVISION:
    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------
    1.0                                       creacion del paquete
    2.0        20181214    Guillermo Prieto   Modificacion del paquete para incluir el procedimiento
                                              de las notificaciones
                                              acuerdo a lo solicitado en el req 3 Notificacion por 
                                              cambio a estado Suspendido del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Cada vez que se Rechace una planilla o un Formulario de Movimiento de Mercancia, 
                                              a los usuarios del sistema de la compania a la que pertenece la placa y/o 
                                              el formulario le debe llegar la notificacion del rechazo, en la cual debe aparecer:
                                              Suspendida: Placa XXX, documento (planilla o transito) XXXX. fecha y hora de rechazo.
                                              (si es placa para planilla de recepcion).
                                              Rechazado: Formulario ####. fecha y hora de rechazo.(si es Formulario de movimiento
                                              de mercancia).
    3.0        20190301    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles 
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
    4.0        20190517    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              acuerdo a lo indicado en el bug 8:
                                              En la pantalla de usuario calificado registro 
                                              sale error cuando se hace click sobre el boton
                                              CARGAR EXCEL.
                                              Se coloca el manejo de excepciones para controlar 
                                              el error que sale.
     5.0        20191028    Guillermo Prieto  Modificacion del paquete para modificar el procedimiento
                                              para consultar la informacion de los formularios rechazados y
                                              placas suspendidas de la tabla de notificacion de eventos, 
                                              de acuerdo a lo solicitado en la nueva definicion del req 3 de notificacones
                                              que estaba especificado en el documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              y que se cambia de acuerdo a reuniones realizadas con Leandro Santamaria
                                              que las notificaciones deben ser mas abiertas no solo para formularios
                                              rechazados y placas suspendidas, que se puedan ingresar otras notificaciones
                                              para esto se va a guardar la informacion en la base de datos. dllo06  cc15
     6.0        20191128    Guillermo Prieto  Modificacion del paquete para modificar el procedimiento
                                              para consultar las notificaciones de formularios de importacion 
                                              de la tabla de notificacion de eventos, adicionanado la tabla no notificar a
                                              usuarios y agregar el campo identificacion en el filtro de las notificaciones 
                                              si este campo viene con algun valor, si no trae valor se consultan todas
                                              las notificaciones para que se puedan ingresar otras notificaciones
                                              para esto se va a guardar la informacion en la base de datos. dllo05  cc3
    5.0        20190605    Guillermo Prieto   Modificacion del paquete para incluir los campos para el requerimiento de 
                                              optimizacion de imagenes:
                                              - RUTA_FINAL (ubicacion del archivo optimizado)
                                              - OBSERVACION (Manejo de excepciones al optimizar, como un log) 
                                              - FECHA_OPTIMIZACION (Fecha en la que es optimizado un archivo)
                                              - DURACION_OPTIMIZADO (Tiempo en que tarda completar la optimizacion de un archivo)
                                              - TAMANO_ARCHIV_ORIG
                                              - TAMANO_ARCHIV_OPTI                                              
                                              de acuerdo al documento
                                             --   VCHRUTA_FINAL          VARCHAR2(1000),
                                              --   VCHOBSERVACION         VARCHAR2(2000),
                                              --   FEOPTIMIZACION         DATE,
                                              --   DTDURACION_OPTIMIZADO  DATE,
                                              --   NMTAMANO_ARCHIV_OPTI   NUMBER(9)                                              .
   6.0         20191212    Guillermo Prieto   Modificacion del paquete para incluir el procedimiento que para
                                              insertar las  notificaciones de los documentos de transporte por 
                                              compania de acuerdo al nuevo desarrollo
                                              de planillas de envio de la dian para precargar la informacion de 
                                              acuerdo a la historia de usuario 6 del documento
                                              F01-PS030223 Levantamiento de Requisitos Planilla de Envio
                                              CC17  DLLO06
     6.0        20191028    Guillermo Prieto  Modificacion del paquete para modificar el procedimiento
                                              para consultar la informacion de los formularios rechazados y
                                              placas suspendidas de la tabla de notificacion de eventos, 
                                              de acuerdo a lo solicitado en la nueva definicion del req 3 de notificacones
                                              que estaba especificado en el documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              y que se cambia de acuerdo a reuniones realizadas con Leandro Santamaria
                                              que las notificaciones deben ser mas abiertas no solo para formularios
                                              rechazados y placas suspendidas, que se puedan ingresar otras notificaciones
                                              para esto se va a guardar la informacion en la base de datos. dllo06  cc15
*****************************************************************************************/

-- Variables
    prcrRecord                              rtytzfw_transitos_documentos;
    prcrRecordCam                           rtytzfw_camiones;
    sqlfound                                boolean;
    sqlSuccess                              boolean;

-- Tipos/subtipos registro
  subtype rtyAdmon_errores                  is zfstzfw_admon_errores.rtytzfw_admon_errores;
--variables
    prcrErrRecord                           rtyAdmon_errores;
    objeto_error                            varchar2(128);
    ocblMensaje                             clob;
    prcrRecordNotific                       rtytzfw_notificac_eventos;

----------------------------------------------------------- SetTransitoDocumento.prc ----------------------------------
procedure SetTransitoDocumento
is
begin
    select sci_transito_documento.nextval into prcrRecord.nmtransito_documento  from dual;
    return;
end SetTransitoDocumento;
------------------------------------------------- Insert$.prc ---------------------------------------------------------
procedure Insert$(
    ircrRecord                      in      rtytzfw_transitos_documentos)
is
   vchValor                         tzfw_parametros.dsvalor%type;
   vchTipo                          char(1);
   vchTransitos                     varchar2(50);
   vchOtros                         varchar2(50);
   vchcdplaca                       TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type;
   vchcdcia_usuaria                 TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type;
   vfeingreso                       TZFW_TRANSITOS_DOCUMENTOS.FEINGRESO%type;
   Vnmtransito_Documento            TZFW_TRANSITOS_DOCUMENTOS.NMTRANSITO_DOCUMENTO%type;
   vchruta                          TZFW_PARAMETROS.DSVALOR%type;
   vchruta_completa                 TZFW_PATHCIA_X_PLACA.DSRUTA%TYPE;
   vfecha                           varchar2(20);
   vchnmtransito_Documento          varchar2(10);
   nmTotal_Reg_Documentos           number(3) := 0;
   nmbnmdoctransporte               TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type;
   vchsngranel_nal_BD               TZFW_TRANSITOS_DOCUMENTOS.SNGRANEL_NAL%type  := 'N';  
   vchsnparcial_BD                  TZFW_DOCUMENTOS_X_CIA.SNPARCIAL%type  := 'N';  

   vchcdplaca_1                     TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type := ' ';
   vfeingreso_1                     TZFW_TRANSITOS_DOCUMENTOS.FEINGRESO%type := NULL;
   vchcdcia_usuaria_1               TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type := ' ';
   vnmtransito_Documento_1          TZFW_TRANSITOS_DOCUMENTOS.NMTRANSITO_DOCUMENTO%type := 0;

   vchcdplaca_2                     TZFW_DOCUMENTOS_X_CIA.CDPLACA%type := ' ';
   vfeingreso_2                     TZFW_DOCUMENTOS_X_CIA.FEINGRESO%type := NULL;
   vchcdcia_usuaria_2               TZFW_DOCUMENTOS_X_CIA.CDCIA_USUARIA%type := ' ';
   vnmtransito_Documento_2          TZFW_DOCUMENTOS_X_CIA.NMTRANSITO_DOCUMENTO%type := 0;

   vchcdtipo_documento              TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type;

   Cursor  cuTotal_Reg_Documentos (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                   ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                   ipvchcdplaca TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type,
                                   ipvchcdtipo_documento TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select count(0) Total_reg 
   from   tzfw_transitos_documentos t3, tzfw_tipos_ingreso ti 
   where  t3.cdtipo_documento = ti.cdtipo_ingreso
   and    ti.nacional = 'S'
   and    t3.cdcia_usuaria = ipcdcia_usuaria
   and    t3.nmdoctransporte = ipnmdoctransporte
   and    t3.cdtipo_documento = ipvchcdtipo_documento;


   Cursor  cuTransitos_Documentos (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                   ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                   ipvchcdplaca TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type,
                                   ipvchcdtipo_documento TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select cdplaca, feingreso, cdcia_usuaria, nmtransito_Documento
   from   tzfw_transitos_documentos t3, tzfw_tipos_ingreso ti 
   where  t3.cdtipo_documento = ti.cdtipo_ingreso
   and    ti.nacional = 'S'
   and    t3.cdcia_usuaria = ipcdcia_usuaria
   and    t3.nmdoctransporte = ipnmdoctransporte
   and    t3.cdtipo_documento  = ipvchcdtipo_documento
   order by t3.feingreso;

   Cursor  cuDocumentos_x_cia  (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                ipvchcdtipo_documento TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select dc.cdplaca, dc.feingreso, dc.cdcia_usuaria, dc.nmtransito_Documento
   from   tzfw_transitos_documentos td,
          tzfw_documentos_x_cia  dc, 
          tzfw_tipos_ingreso ti 
   where  td.cdplaca = dc.cdplaca
   and    td.feingreso = dc.feingreso
   and    td.cdcia_usuaria = dc.cdcia_usuaria
   and    td.nmtransito_documento = dc.nmtransito_documento
   and    td.cdtipo_documento = ti.cdtipo_ingreso
   and    ti.nacional = 'S'
   and    td.cdcia_usuaria =  ipcdcia_usuaria
   and    td.nmdoctransporte = ipnmdoctransporte
   and    td.cdtipo_documento  = ipvchcdtipo_documento
   order by td.feingreso;

   Cursor  cuTransitos_Documentos_ip (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                      ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                      ipnmbid           TZFW_TRANSITOS_DOCUMENTOS.ID%type) is
   select cdplaca, feingreso, cdcia_usuaria, nmtransito_Documento
   from   tzfw_transitos_documentos t4 
   where  t4.cdcia_usuaria = ipcdcia_usuaria
   and    t4.nmdoctransporte = ipnmdoctransporte
   and    t4.id = ipnmbid;

   Cursor  cuDocumentos_x_cia_ip  (ipvchcdplaca TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type,
                                   ipfeingreso  TZFW_TRANSITOS_DOCUMENTOS.FEINGRESO%type,
                                   ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                   ipnmtransito_Documento TZFW_TRANSITOS_DOCUMENTOS.NMTRANSITO_DOCUMENTO%type) is
   select snparcial
   from   tzfw_transitos_documentos dc 
   where  dc.cdplaca = ipvchcdplaca
   and    dc.feingreso = ipfeingreso 
   and    dc.cdcia_usuaria = ipcdcia_usuaria
   and    dc.nmtransito_Documento = ipnmtransito_Documento
   and    rownum = 1;

   Cursor  cuGranelNal_Documentos (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type,
                                   ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                   ipvchcdplaca TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type,
                                   ipvchcdtipo_documento TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is    
   select  distinct nvl(td.sngranel_nal,'N')    
   from    TZFW_TRANSITOS_DOCUMENTOS td, tzfw_tipos_ingreso ti
   where   td.cdtipo_documento = ti.cdtipo_ingreso
   and     ti.nacional = 'S'
   and     td.cdcia_usuaria    = ipcdcia_usuaria
   and     td.nmdoctransporte  = ipnmdoctransporte
   and     td.cdtipo_documento  = ipvchcdtipo_documento
   and     td.cdplaca         != ipvchcdplaca;

   Cursor  cusnparcial_Documentos_cia (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                       ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                       ipvchcdtipo_documento TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select distinct nvl(dc.snparcial,'N')
   from   tzfw_transitos_documentos td,
          tzfw_documentos_x_cia  dc, 
          tzfw_tipos_ingreso ti
   where  td.cdplaca = dc.cdplaca
   and    td.feingreso = dc.feingreso
   and    td.cdcia_usuaria = dc.cdcia_usuaria
   and    td.nmtransito_documento = dc.nmtransito_documento
   and    td.cdtipo_documento = ti.cdtipo_ingreso
   and    ti.nacional = 'S'
   and    td.cdcia_usuaria = ipcdcia_usuaria
   and    td.nmdoctransporte = ipnmdoctransporte
   and    td.cdtipo_documento  = ipvchcdtipo_documento;


begin
/****************************************************************************************
    3.0        20190301    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles 
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
*****************************************************************************************/
    vchValor := '0';
    prcrRecord := ircrRecord;
    prcrRecord.sncierre := 'N';
    prcrRecord.sninconsistencia  := 'N';
    prcrRecord.sngranvolumen := nvl(prcrRecord.sngranvolumen,'N');
    prcrRecord.snparcial := nvl(prcrRecord.snparcial,'N');
    prcrRecord.sngranel_nal := nvl(prcrRecord.sngranel_nal,'N');
    SetTransitoDocumento;


    insert into TZFW_TRANSITOS_DOCUMENTOS values prcrRecord;
    sqlsuccess := sql%rowcount > 0;

    vchcdplaca :=ircrRecord.cdplaca;
    vchcdcia_usuaria :=ircrRecord.cdcia_usuaria;
    vfeingreso := ircrRecord.feingreso;
    vnmtransito_Documento :=prcrRecord.nmtransito_Documento;
    nmbnmdoctransporte    :=prcrRecord.nmdoctransporte;
    vchcdtipo_documento   :=prcrRecord.cdtipo_documento;

   open cuGranelNal_Documentos(vchcdcia_usuaria, 
                               nmbnmdoctransporte,
                               vchcdtipo_documento,
                               vchcdplaca);
   --open cuGranelNal_Documentos(prcrRecord.cdcia_usuaria, 
   --                            prcrRecord.nmdoctransporte);

   fetch cuGranelNal_Documentos into vchsngranel_nal_BD;
   close cuGranelNal_Documentos;   

   open cusnparcial_Documentos_cia(vchcdcia_usuaria, 
                                   nmbnmdoctransporte,
                                   vchcdtipo_documento);
   --open cusnparcial_Documentos_cia(prcrRecord.cdcia_usuaria, 
   --                            prcrRecord.nmdoctransporte);

   fetch cusnparcial_Documentos_cia into vchsnparcial_BD;
   close cusnparcial_Documentos_cia; 

    --SE LE QUITA EL FORMATO A LA FECHA
    vfecha:= TO_CHAR(vfeingreso,'ddmmyyyyHHMISS');
    --SE CONVIERTE DE NUMBER A VARCHAR
    vchnmtransito_Documento:=to_char(vnmtransito_Documento);

    --SE CREA LA RUTA
    SELECT DSVALOR INTO vchruta FROM TZFW_PARAMETROS WHERE DSPARAMETRO = 'RUTA_PLACAS';
    vchruta_completa:= vchruta||vchcdcia_usuaria||vchcdplaca||vfecha||vchnmtransito_Documento;

    --INSERTA EN LA NUEVA TABLA TZFW_PATHCIA_X_PLACA
    INSERT INTO TZFW_PATHCIA_X_PLACA (CDCIA_USUARIA,CDPLACA,FEINGRESO,NMTRANSITO_DOCUMENTO,DSRUTA)
    VALUES(vchcdcia_usuaria,vchcdplaca,VFEINGRESO,VNMTRANSITO_DOCUMENTO,vchruta_completa);



    -- si el tipo de ingreso es planilla de envio o transitos
    if (vchTipo ='T') then
      -- Cuando se marca o desmarca el check de gran volumen de una placa que esta asociada a una planilla de envio
      -- o un transito aduanero, modifica todas las placas que estan asociadas al mismo documento
      update tzfw_transitos_documentos x
      set x.sngranvolumen = prcrRecord.Sngranvolumen
      where x.nmtransito = prcrRecord.Nmtransito;

    end if;
    if (prcrRecord.Cdtipo_Documento = '001') then -- si es planilla de envio
      update tzfw_transitos_documentos x
      set x.sngranvolumen = prcrRecord.Sngranvolumen
      where x.nmdoctransporte = prcrRecord.nmdoctransporte;
    end if;

    if (prcrRecord.sngranel_nal= 'S' and vchsngranel_nal_BD =  'N' and prcrRecord.snparcial =  'N' ) then -- si es Granel Nal(S) 
     begin--1
     if  (vchsnparcial_BD  =  'S' or vchsnparcial_BD  =  'N') Then
        -- actualizar sngranel_nal y snparcial todas las placas que estan asociadas al mismo numero de tipo de documento
        -- tanto en la tabla tzfw_transitos_documentos como en la tabla tzfw_documentos_x_cia
        -- cursor con el total de registros

        open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                      prcrRecord.nmdoctransporte,
                                      prcrRecord.cdplaca,
                                      vchcdtipo_documento);

        fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
        close  cuTotal_Reg_Documentos; 

        if nmTotal_Reg_Documentos > 0 Then
           --actualizar  el campo SNGRANEL_NAL = 'S'
           --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
           update tzfw_transitos_documentos x
           set    x.sngranel_nal = 'S'
           where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
           and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
           and    x.cdtipo_documento  = vchcdtipo_documento
           and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                          from   tzfw_tipos_ingreso ti
                                          where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                          and    ti.nacional = 'S');
           --and    x.ID               != prcrRecord.ID
           --and    x.cdplaca          != vchcdplaca;
           --actualizar  el campo SNPARCIAL = 'N'
           --de la tabla TZFW_DOCUMENTOS_X_CIA  donde CDCIA_USUARIO,  
           --PLACA, FECHA INGRESO Y TRANSITO DOCUMENTO sean iguales a los que estan ahi:
           open cuTransitos_Documentos(vchcdcia_usuaria, nmbnmdoctransporte , vchcdplaca, vchcdtipo_documento);
           fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
           loop
              Exit When cuTransitos_Documentos%notfound;
              open cuDocumentos_x_cia(prcrRecord.cdcia_usuaria, 
                                      prcrRecord.nmdoctransporte,
                                      vchcdtipo_documento);
              fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;
              loop
                  Exit When cuDocumentos_x_cia%notfound;

                  update tzfw_documentos_x_cia d
                  set    d.snparcial =  'N'
                  where  d.cdplaca   = vchcdplaca_2
                  and    d.feingreso   = vfeingreso_2
                  and    d.cdcia_usuaria  = vchcdcia_usuaria_2
                  and    d.nmtransito_Documento  = vnmtransito_Documento_2;

                  fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;

              End loop;
              close cuDocumentos_x_cia;
              fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
           End loop;
           close cuTransitos_Documentos;
        end if;
     end if;
     end;--1
    else -- no, si es Granel Nal(N)
        -- actualizar sngranel_nal y snparcial todas las placas que estan asociadas al mismo numero de tipo de documento
        -- tanto en la tabla tzfw_transitos_documentos como en la tabla tzfw_documentos_x_cia
        -- cursor con el total de registros
     if (prcrRecord.sngranel_nal= 'N' and prcrRecord.snparcial =  'S' and vchsnparcial_BD  =  'N') then -- si es Granel Nal(S) 
       begin--2
       if (vchsngranel_nal_BD =  'S' OR vchsngranel_nal_BD =  'N') then       
        open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                      prcrRecord.nmdoctransporte,
                                      prcrRecord.id,
                                      vchcdtipo_documento);

        fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
        close  cuTotal_Reg_Documentos; 

        if nmTotal_Reg_Documentos > 0 Then
           --actualizar  el campo SNGRANEL_NAL = 'N'
           --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
           update tzfw_transitos_documentos x
           set    x.sngranel_nal =  'N'
           where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
           and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
           and    x.cdtipo_documento  = vchcdtipo_documento
           and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                          from   tzfw_tipos_ingreso ti
                                          where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                          and    ti.nacional = 'S');
           --and    x.ID               != prcrRecord.ID
           --and    x.cdplaca          != vchcdplaca;
           --actualizar  el campo SNPARCIAL = 'S'
           --de la tabla TZFW_DOCUMENTOS_X_CIA  donde CDCIA_USUARIO,  
           --PLACA, FECHA INGRESO Y TRANSITO DOCUMENTO sean iguales a los que estan ahi:

           open cuTransitos_Documentos(vchcdcia_usuaria, nmbnmdoctransporte, vchcdplaca, vchcdtipo_documento);
           fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
           loop
              Exit When cuTransitos_Documentos%notfound;
              open cuDocumentos_x_cia(prcrRecord.cdcia_usuaria, 
                                      prcrRecord.nmdoctransporte,
                                      vchcdtipo_documento);
              fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;
              loop
                  Exit When cuDocumentos_x_cia%notfound;

                  update tzfw_documentos_x_cia d
                  set    d.snparcial =  'S'
                  where  d.cdplaca   = vchcdplaca_2
                  and    d.feingreso   = vfeingreso_2
                  and    d.cdcia_usuaria  = vchcdcia_usuaria_2
                  and    d.nmtransito_Documento  = vnmtransito_Documento_2;

                  fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;
              End loop;
              close cuDocumentos_x_cia;
             fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
           End loop;
           close cuTransitos_Documentos;
        end if;    
       end if;
       end;--2
       else
           if (prcrRecord.sngranel_nal= 'N' and vchsngranel_nal_BD =  'S' and prcrRecord.snparcial =  'N' and vchsnparcial_BD  =  'N') then -- si es Granel Nal(S) 
               begin--3
                   open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                                 prcrRecord.nmdoctransporte,
                                                 prcrRecord.id,
                                                 vchcdtipo_documento);

                   fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
                   close  cuTotal_Reg_Documentos; 

                   if nmTotal_Reg_Documentos > 0 Then
                      --actualizar  el campo SNGRANEL_NAL = 'N'
                      --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
                      update tzfw_transitos_documentos x
                      set    x.sngranel_nal =  'N'
                      where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
                      and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
                      and    x.cdtipo_documento  = vchcdtipo_documento
                      and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                                     from   tzfw_tipos_ingreso ti
                                                     where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                                     and    ti.nacional = 'S');
                    end if; 
               end;--3
           else
               if (prcrRecord.sngranel_nal= 'N' and vchsngranel_nal_BD =  'N' and prcrRecord.snparcial =  'N' and vchsnparcial_BD  =  'S') then -- si es Granel Nal(S) 
                  begin--4
                      -- actualizar snparcial todas las placas que estan asociadas al mismo numero de tipo de documento
                      -- tanto en la tabla tzfw_transitos_documentos como en la tabla tzfw_documentos_x_cia
                      -- cursor con el total de registros

                      open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                                    prcrRecord.nmdoctransporte,
                                                    prcrRecord.cdplaca,
                                                    vchcdtipo_documento);

                      fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
                      close  cuTotal_Reg_Documentos; 

                      if nmTotal_Reg_Documentos > 0 Then
                         --actualizar  el campo SNPARCIAL = 'N'
                         --de la tabla TZFW_DOCUMENTOS_X_CIA  donde CDCIA_USUARIO,  
                         --PLACA, FECHA INGRESO Y TRANSITO DOCUMENTO sean iguales a los que estan ahi:
                         open cuTransitos_Documentos(vchcdcia_usuaria, nmbnmdoctransporte, vchcdplaca, vchcdtipo_documento);
                         fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
                         loop
                            Exit When cuTransitos_Documentos%notfound;
                            open cuDocumentos_x_cia(prcrRecord.cdcia_usuaria, 
                                                    prcrRecord.nmdoctransporte,
                                                    vchcdtipo_documento);
                            fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;
                            loop
                               Exit When cuDocumentos_x_cia%notfound;

                               update tzfw_documentos_x_cia d
                               set    d.snparcial =  'N'
                               where  d.cdplaca   = vchcdplaca_2
                               and    d.feingreso   = vfeingreso_2
                               and    d.cdcia_usuaria  = vchcdcia_usuaria_2
                               and    d.nmtransito_Documento  = vnmtransito_Documento_2;

                               fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;

                            End loop;
                            close cuDocumentos_x_cia;
                            fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
                         End loop;
                         close cuTransitos_Documentos;
                      end if; 
                  end;--4
                  else
                      if (prcrRecord.sngranel_nal= 'S' and vchsngranel_nal_BD =  'N' and prcrRecord.snparcial =  'N' and vchsnparcial_BD  =  'N') then -- solo  actualiza Granel Nal(S) 
                          begin--5
                              open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                                            prcrRecord.nmdoctransporte,
                                                            prcrRecord.cdplaca,
                                                            vchcdtipo_documento);

                              fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
                              close  cuTotal_Reg_Documentos; 

                              if nmTotal_Reg_Documentos > 0 Then
                                 --actualizar  el campo SNGRANEL_NAL = 'S'
                                 --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
                                 update tzfw_transitos_documentos x
                                 set    x.sngranel_nal = 'S'
                                 where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
                                 and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
                                 and    x.cdtipo_documento  = vchcdtipo_documento
                                 and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                                                from   tzfw_tipos_ingreso ti
                                                                where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                                                and    ti.nacional = 'S');
                              end if; 
                          end;--5
                          else
                              if (prcrRecord.sngranel_nal= 'N'  and vchsnparcial_BD  =  'S' and prcrRecord.snparcial =  'N' and vchsnparcial_BD  =  'N') then -- solo  actualiza Granel Nal(N) 
                                 begin--6
                                    open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                                                  prcrRecord.nmdoctransporte,
                                                                  prcrRecord.cdplaca,
                                                                  vchcdtipo_documento);

                                    fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
                                    close  cuTotal_Reg_Documentos; 

                                    if nmTotal_Reg_Documentos > 0 Then
                                       --actualizar  el campo SNGRANEL_NAL = 'S'
                                       --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
                                       update tzfw_transitos_documentos x
                                       set    x.sngranel_nal = 'N'
                                       where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
                                       and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
                                       and    x.cdtipo_documento  = vchcdtipo_documento
                                       and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                                                      from   tzfw_tipos_ingreso ti
                                                                      where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                                                      and    ti.nacional = 'S');
                                    end if; 
                                 end;--6
                              end if;--6 
                      end if;--5 
                end if;--4 
           end if; --3
      end if;--2   
    end if; --1  
    return;
end Insert$;
-----------------------------------------------------------Update$.prc ------------------------------------------------
procedure Update$(
    ircrRecord                     in       rtytzfw_transitos_documentos)
is
   vchTransitos                     varchar2(50);
   vruta                            VARCHAR2(200);
   vruta_completa                   VARCHAR2(200);
   vexiste                          number;
   vchcdplaca                       TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type;
   vchcdcia_usuaria                 TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type;
   vfeingreso                       TZFW_TRANSITOS_DOCUMENTOS.FEINGRESO%type;
   Vnmtransito_Documento            TZFW_TRANSITOS_DOCUMENTOS.NMTRANSITO_DOCUMENTO%type;
   vchruta                          TZFW_PARAMETROS.DSVALOR%type;
   vchruta_completa                 TZFW_PATHCIA_X_PLACA.DSRUTA%TYPE;
   vfebascula                       tzfw_camiones.febascula%TYPE;
   vfecha                           varchar2(20);
   vchnmtransito_Documento          varchar2(10);
   nmTotal_Reg_Documentos           number(3) := 0;
   nmbTotal                         number;
   nmbnmdoctransporte               TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type;
   vchsngranel_nal_BD               TZFW_TRANSITOS_DOCUMENTOS.SNGRANEL_NAL%type  := 'N';  
   vchsnparcial_BD                  TZFW_DOCUMENTOS_X_CIA.SNPARCIAL%type  := 'N';  

   vchcdplaca_1                     TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type := ' ';
   vfeingreso_1                     TZFW_TRANSITOS_DOCUMENTOS.FEINGRESO%type := NULL;
   vchcdcia_usuaria_1               TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type := ' ';
   vnmtransito_Documento_1          TZFW_TRANSITOS_DOCUMENTOS.NMTRANSITO_DOCUMENTO%type := 0;

   vchcdplaca_2                     TZFW_DOCUMENTOS_X_CIA.CDPLACA%type := ' ';
   vfeingreso_2                     TZFW_DOCUMENTOS_X_CIA.FEINGRESO%type := NULL;
   vchcdcia_usuaria_2               TZFW_DOCUMENTOS_X_CIA.CDCIA_USUARIA%type := ' ';
   vnmtransito_Documento_2          TZFW_DOCUMENTOS_X_CIA.NMTRANSITO_DOCUMENTO%type := 0;

   vchcdtipo_documento              TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type  := ' '; 

   Cursor  cuTotal_Reg_Documentos (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                   ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                   ipnmbid           TZFW_TRANSITOS_DOCUMENTOS.ID%type,
                                   ipvchcdtipo_documento TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select count(0) Total_reg from tzfw_transitos_documentos t3, tzfw_tipos_ingreso ti  
   where  t3.cdtipo_documento = ti.cdtipo_ingreso
   and    ti.nacional = 'S'
   and    t3.cdcia_usuaria = ipcdcia_usuaria
   and    t3.nmdoctransporte = ipnmdoctransporte
   and    t3.cdtipo_documento = ipvchcdtipo_documento;

   Cursor  cuTransitos_Documentos (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                   ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                   ipvchcdtipo_documento TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select cdplaca, feingreso, cdcia_usuaria, nmtransito_Documento
   from   tzfw_transitos_documentos t3, tzfw_tipos_ingreso ti  
   where  t3.cdtipo_documento = ti.cdtipo_ingreso
   and    ti.nacional = 'S'
   and    t3.cdcia_usuaria = ipcdcia_usuaria
   and    t3.nmdoctransporte = ipnmdoctransporte
   and    t3.cdtipo_documento = ipvchcdtipo_documento;

   Cursor  cuDocumentos_x_cia  (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                ipvchcdtipo_documento TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select dc.cdplaca, dc.feingreso, dc.cdcia_usuaria, dc.nmtransito_Documento
   from   tzfw_transitos_documentos td,
          tzfw_documentos_x_cia  dc,
          tzfw_tipos_ingreso ti 
   where  td.cdplaca = dc.cdplaca
   and    td.feingreso = dc.feingreso
   and    td.cdcia_usuaria = dc.cdcia_usuaria
   and    td.nmtransito_documento = dc.nmtransito_documento
   and    td.cdtipo_documento = ti.cdtipo_ingreso
   and    ti.nacional = 'S'
   and    td.cdcia_usuaria =  ipcdcia_usuaria
   and    td.nmdoctransporte = ipnmdoctransporte
   and    td.cdtipo_documento = ipvchcdtipo_documento;


   Cursor  cuGranelNal_Documentos (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type,
                                   ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type,
                                   ipvchcdplaca TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type) is    
   select  distinct  nvl(td.sngranel_nal,'N')    
   from    TZFW_TRANSITOS_DOCUMENTOS td, tzfw_tipos_ingreso ti 
   where   td.cdtipo_documento = ti.cdtipo_ingreso
   and     ti.nacional = 'S'
   and     td.cdcia_usuaria = ipcdcia_usuaria
   and     td.nmdoctransporte = ipnmdoctransporte
   and     td.cdplaca        != ipvchcdplaca;

   Cursor  cusnparcial_Documentos_cia (ipcdcia_usuaria   TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type, 
                                       ipnmdoctransporte TZFW_TRANSITOS_DOCUMENTOS.NMDOCTRANSPORTE%type) is
   select distinct nvl(dc.snparcial,'N')
   from   tzfw_transitos_documentos td,
          tzfw_documentos_x_cia  dc,
          tzfw_tipos_ingreso ti 
   where  td.cdplaca = dc.cdplaca
   and    td.feingreso = dc.feingreso
   and    td.cdcia_usuaria = dc.cdcia_usuaria
   and    td.nmtransito_documento = dc.nmtransito_documento
   and    td.cdtipo_documento = ti.cdtipo_ingreso
   and    ti.nacional = 'S'
   and    td.cdcia_usuaria = ipcdcia_usuaria
   and    td.nmdoctransporte = ipnmdoctransporte;

begin
/****************************************************************************************
    3.0        20190301    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles 
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
*****************************************************************************************/

   prcrRecord := ircrRecord;

   prcrRecord.snparcial := nvl(prcrRecord.snparcial,'N');
   prcrRecord.sngranel_nal := nvl(prcrRecord.sngranel_nal,'N');

   vchcdplaca :=ircrRecord.cdplaca;
   vchcdcia_usuaria :=ircrRecord.cdcia_usuaria;
   vfeingreso := ircrRecord.feingreso;
   vnmtransito_Documento :=prcrRecord.nmtransito_Documento;
   nmbnmdoctransporte    :=prcrRecord.nmdoctransporte;
   vchcdtipo_documento  :=prcrRecord.cdtipo_documento;

   open cuGranelNal_Documentos(prcrRecord.cdcia_usuaria, 
                               prcrRecord.nmdoctransporte,
                               vchcdplaca);

   fetch cuGranelNal_Documentos into vchsngranel_nal_BD;
   close cuGranelNal_Documentos;   


    open cusnparcial_Documentos_cia(prcrRecord.cdcia_usuaria, 
                               prcrRecord.nmdoctransporte);

   fetch cusnparcial_Documentos_cia into vchsnparcial_BD;
   close cusnparcial_Documentos_cia;   
   
   -- mirsan 20220118
   -- se consulta si la placa ya fue enviada previamente
  /*  select count(1)
    into nmbTotal
    from tzfw_audit_planilla
    where cdcia_usuaria=prcrRecord.cdcia_usuaria
    and cdplaca= prcrRecord.cdplaca
    and feingreso=prcrRecord.feingreso
    and (cdvalor_actual ='T' or cdvalor_anterior='T');
    
    -- de ser asi no debe modificarse el campo tipo desprecinte y comentarios del desprecinte
    if nmbTotal > 0 then
        select CDTIPODESPRECINTE,DSCOMENTARIODESPRE
        into prcrRecord.CDTIPODESPRECINTE   , prcrRecord.DSCOMENTARIODESPRE
        from TZFW_camiones
        where cdplaca = prcrRecord.cdplaca
        and feingreso = prcrRecord.feingreso;
    end if;*/

       UPDATE TZFW_TRANSITOS_DOCUMENTOS
           SET ROW = prcrRecord
        WHERE   CDPLACA   = prcrRecord.cdplaca
        AND     FEINGRESO = prcrRecord.feingreso
        AND     CDCIA_USUARIA = prcrRecord.cdcia_usuaria
        AND     NMTRANSITO_DOCUMENTO = prcrRecord.nmtransito_documento;
        sqlsuccess := sql%rowcount > 0;

    SELECT COUNT(*)INTO VEXISTE FROM TZFW_PATHCIA_X_PLACA
    WHERE   CDPLACA   = PRCRRECORD.CDPLACA
    AND     FEINGRESO = PRCRRECORD.FEINGRESO
    AND     CDCIA_USUARIA = PRCRRECORD.CDCIA_USUARIA
    AND     NMTRANSITO_DOCUMENTO = PRCRRECORD.NMTRANSITO_DOCUMENTO;

    IF(VEXISTE=0)THEN
        vchcdplaca :=ircrRecord.cdplaca;
        vchcdcia_usuaria :=ircrRecord.cdcia_usuaria;
        vfeingreso := ircrRecord.feingreso;
        vnmtransito_Documento :=prcrRecord.nmtransito_Documento;
        --SE LE QUITA EL FORMATO A LA FECHA
        vfecha:= TO_CHAR(vfeingreso,'ddmmyyyyHHMISS');
        --SE CONVIERTE DE NUMBER A VARCHAR
        vchnmtransito_Documento:=to_char(vnmtransito_Documento);

        --SE CREA LA RUTA
        SELECT DSVALOR INTO vchruta FROM TZFW_PARAMETROS WHERE DSPARAMETRO = 'RUTA_PLACAS';
        vchruta_completa:= vchruta||vchcdcia_usuaria||vchcdplaca||vfecha||vchnmtransito_Documento;

        --INSERTA EN LA NUEVA TABLA TZFW_PATHCIA_X_PLACA
        INSERT INTO TZFW_PATHCIA_X_PLACA (CDCIA_USUARIA,CDPLACA,FEINGRESO,NMTRANSITO_DOCUMENTO,DSRUTA)
        VALUES(vchcdcia_usuaria,vchcdplaca,VFEINGRESO,VNMTRANSITO_DOCUMENTO,vchruta_completa);
    END IF;

    -- consulta si la placa tiene fecha de bascula, si tiene fecha de bascula no debe permitir actualizar
    select febascula  into vfebascula
    from tzfw_camiones c, tzfw_cias_x_camion ca
    where
            c.cdplaca = ca.cdplaca
    and     c.feingreso = ca.feingreso
    and     ca.cdplaca   = prcrrecord.cdplaca
    and     ca.feingreso = prcrrecord.feingreso
    and     ca.cdcia_usuaria = prcrrecord.cdcia_usuaria;

     -- consulta tipos de ingreso de transito de documentos
    select INSTR(dsvalor,prcrRecord.Cdtipo_Documento)
    into vchTransitos
    from tzfw_parametros where dsparametro='TRANSITO';

    -- si el tipo de ingreso es planilla de envio o transitos
    --and vfebascula is null
    if (vchTransitos !='0') then
      -- Cuando se marca o desmarca el check de gran volumen de una placa que esta asociada a una planilla de envio
      -- o un transito aduanero, modifica todas las placas que estan asociadas al mismo documento
          update tzfw_transitos_documentos x
          set x.sngranvolumen = prcrRecord.Sngranvolumen
          where x.nmtransito = prcrRecord.Nmtransito;
    end if;
    if (prcrRecord.Cdtipo_Documento = '001'  ) then -- si es planilla de envio

          update tzfw_transitos_documentos x
          set x.sngranvolumen = prcrRecord.Sngranvolumen
          where x.nmdoctransporte = prcrRecord.nmdoctransporte;
    end if;


    if (prcrRecord.sngranel_nal= 'S' and vchsngranel_nal_BD =  'N' and prcrRecord.snparcial =  'N' ) then -- si es Granel Nal(S) 
     begin--1
     if  (vchsnparcial_BD  =  'S' or vchsnparcial_BD  =  'N') Then
        -- actualizar sngranel_nal y snparcial todas las placas que estan asociadas al mismo numero de tipo de documento
        -- tanto en la tabla tzfw_transitos_documentos como en la tabla tzfw_documentos_x_cia
        -- cursor con el total de registros

        open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                      prcrRecord.nmdoctransporte,
                                      prcrRecord.id,
                                      vchcdtipo_documento);

        fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
        close  cuTotal_Reg_Documentos; 

        if nmTotal_Reg_Documentos > 0 Then
           --actualizar  el campo SNGRANEL_NAL = 'S'
           --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
           update tzfw_transitos_documentos x
           set    x.sngranel_nal = 'S'
           where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
           and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
           and    x.cdtipo_documento  = vchcdtipo_documento
           and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                          from   tzfw_tipos_ingreso ti
                                          where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                          and    ti.nacional = 'S');
           --and    x.ID               != prcrRecord.ID
           --and    x.cdplaca          != vchcdplaca;
           --actualizar  el campo SNPARCIAL = 'N'
           --de la tabla TZFW_DOCUMENTOS_X_CIA  donde CDCIA_USUARIO,  
           --PLACA, FECHA INGRESO Y TRANSITO DOCUMENTO sean iguales a los que estan ahi:
           open cuTransitos_Documentos(vchcdcia_usuaria, nmbnmdoctransporte,  vchcdtipo_documento);
           fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
           loop
              Exit When cuTransitos_Documentos%notfound;
              open cuDocumentos_x_cia(prcrRecord.cdcia_usuaria, 
                                      prcrRecord.nmdoctransporte,
                                      vchcdtipo_documento);
              fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;
              loop
                  Exit When cuDocumentos_x_cia%notfound;

                  update tzfw_documentos_x_cia d
                  set    d.snparcial =  'N'
                  where  d.cdplaca   = vchcdplaca_2
                  and    d.feingreso   = vfeingreso_2
                  and    d.cdcia_usuaria  = vchcdcia_usuaria_2
                  and    d.nmtransito_Documento  = vnmtransito_Documento_2;

                  fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;

              End loop;
              close cuDocumentos_x_cia;
              fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
           End loop;
           close cuTransitos_Documentos;
        end if;
     end if;
     end;--1
    else -- no, si es Granel Nal(N)
        -- actualizar sngranel_nal y snparcial todas las placas que estan asociadas al mismo numero de tipo de documento
        -- tanto en la tabla tzfw_transitos_documentos como en la tabla tzfw_documentos_x_cia
        -- cursor con el total de registros
     if (prcrRecord.sngranel_nal= 'N' and prcrRecord.snparcial =  'S' and vchsnparcial_BD  =  'N') then -- si es Granel Nal(S) 
       begin--2
       if (vchsngranel_nal_BD =  'S' OR vchsngranel_nal_BD =  'N') then
        open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                      prcrRecord.nmdoctransporte,
                                      prcrRecord.id,
                                      vchcdtipo_documento);

        fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
        close  cuTotal_Reg_Documentos; 

        if nmTotal_Reg_Documentos > 0 Then
           --actualizar  el campo SNGRANEL_NAL = 'N'
           --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
           update tzfw_transitos_documentos x
           set    x.sngranel_nal =  'N'
           where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
           and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
           and    x.cdtipo_documento  = vchcdtipo_documento
           and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                          from   tzfw_tipos_ingreso ti
                                          where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                          and    ti.nacional = 'S');
           --and    x.ID               != prcrRecord.ID
           --and    x.cdplaca          != vchcdplaca;
           --actualizar  el campo SNPARCIAL = 'S'
           --de la tabla TZFW_DOCUMENTOS_X_CIA  donde CDCIA_USUARIO,  
           --PLACA, FECHA INGRESO Y TRANSITO DOCUMENTO sean iguales a los que estan ahi:

           open cuTransitos_Documentos(vchcdcia_usuaria, nmbnmdoctransporte,  vchcdtipo_documento);
           fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
           loop
              Exit When cuTransitos_Documentos%notfound;
              open cuDocumentos_x_cia(prcrRecord.cdcia_usuaria, 
                                      prcrRecord.nmdoctransporte,
                                      vchcdtipo_documento);
              fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;
              loop
                  Exit When cuDocumentos_x_cia%notfound;

                  update tzfw_documentos_x_cia d
                  set    d.snparcial =  'S'
                  where  d.cdplaca   = vchcdplaca_2
                  and    d.feingreso   = vfeingreso_2
                  and    d.cdcia_usuaria  = vchcdcia_usuaria_2
                  and    d.nmtransito_Documento  = vnmtransito_Documento_2;

                  fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;
              End loop;
              close cuDocumentos_x_cia;
             fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
           End loop;
           close cuTransitos_Documentos;
        end if;    
       end if;
       end;--2
       else
           if (prcrRecord.sngranel_nal= 'N' and vchsngranel_nal_BD =  'S' and prcrRecord.snparcial =  'N' and vchsnparcial_BD  =  'N') then -- si es Granel Nal(S) 
               begin--3
                   open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                                 prcrRecord.nmdoctransporte,
                                                 prcrRecord.id,
                                                 vchcdtipo_documento);

                   fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
                   close  cuTotal_Reg_Documentos; 

                   if nmTotal_Reg_Documentos > 0 Then
                      --actualizar  el campo SNGRANEL_NAL = 'N'
                      --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
                      update tzfw_transitos_documentos x
                      set    x.sngranel_nal =  'N'
                      where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
                      and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
                      and    x.cdtipo_documento  = vchcdtipo_documento
                      and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                                     from   tzfw_tipos_ingreso ti
                                                     where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                                     and    ti.nacional = 'S');
                    end if; 
               end;--3
           else
               if (prcrRecord.sngranel_nal= 'N' and vchsngranel_nal_BD =  'N' and prcrRecord.snparcial =  'N' and vchsnparcial_BD  =  'S') then -- si es Granel Nal(S) 
                  begin--4
                      -- actualizar snparcial todas las placas que estan asociadas al mismo numero de tipo de documento
                      -- tanto en la tabla tzfw_transitos_documentos como en la tabla tzfw_documentos_x_cia
                      -- cursor con el total de registros

                      open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                                    prcrRecord.nmdoctransporte,
                                                    prcrRecord.id,
                                                    vchcdtipo_documento);

                      fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
                      close  cuTotal_Reg_Documentos; 

                      if nmTotal_Reg_Documentos > 0 Then
                         --actualizar  el campo SNPARCIAL = 'N'
                         --de la tabla TZFW_DOCUMENTOS_X_CIA  donde CDCIA_USUARIO,  
                         --PLACA, FECHA INGRESO Y TRANSITO DOCUMENTO sean iguales a los que estan ahi:
                         open cuTransitos_Documentos(vchcdcia_usuaria, nmbnmdoctransporte, vchcdtipo_documento);
                         fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
                         loop
                            Exit When cuTransitos_Documentos%notfound;
                            open cuDocumentos_x_cia(prcrRecord.cdcia_usuaria, 
                                                    prcrRecord.nmdoctransporte,
                                                    vchcdtipo_documento);
                            fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;
                            loop
                               Exit When cuDocumentos_x_cia%notfound;

                               update tzfw_documentos_x_cia d
                               set    d.snparcial =  'N'
                               where  d.cdplaca   = vchcdplaca_2
                               and    d.feingreso   = vfeingreso_2
                               and    d.cdcia_usuaria  = vchcdcia_usuaria_2
                               and    d.nmtransito_Documento  = vnmtransito_Documento_2;

                               fetch cuDocumentos_x_cia  into  vchcdplaca_2 , vfeingreso_2, vchcdcia_usuaria_2, vnmtransito_Documento_2;

                            End loop;
                            close cuDocumentos_x_cia;
                            fetch cuTransitos_Documentos  into  vchcdplaca_1, vfeingreso_1, vchcdcia_usuaria_1, vnmtransito_Documento_1;
                         End loop;
                         close cuTransitos_Documentos;
                      end if; 
                  end;--4
                  else
                      if (prcrRecord.sngranel_nal= 'S' and vchsngranel_nal_BD =  'N' and prcrRecord.snparcial =  'N' and vchsnparcial_BD  =  'N') then -- solo  actualiza Granel Nal(S) 
                          begin--5
                              open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                                            prcrRecord.nmdoctransporte,
                                                            prcrRecord.cdplaca,
                                                            vchcdtipo_documento);

                              fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
                              close  cuTotal_Reg_Documentos; 

                              if nmTotal_Reg_Documentos > 0 Then
                                 --actualizar  el campo SNGRANEL_NAL = 'S'
                                 --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
                                 update tzfw_transitos_documentos x
                                 set    x.sngranel_nal = 'S'
                                 where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
                                 and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
                                 and    x.cdtipo_documento  = vchcdtipo_documento
                                 and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                                                from   tzfw_tipos_ingreso ti
                                                                where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                                                and    ti.nacional = 'S');
                              end if; 
                          end;--5
                          else
                              if (prcrRecord.sngranel_nal= 'N'   and vchsngranel_nal_BD =  'S' and prcrRecord.snparcial =  'N' and vchsnparcial_BD  =  'N') then -- solo  actualiza Granel Nal(N) 
                                 begin--6
                                    open  cuTotal_Reg_Documentos (prcrRecord.cdcia_usuaria, 
                                                                  prcrRecord.nmdoctransporte,
                                                                  prcrRecord.cdplaca,
                                                                  vchcdtipo_documento);

                                    fetch  cuTotal_Reg_Documentos into nmTotal_Reg_Documentos;                                  
                                    close  cuTotal_Reg_Documentos; 

                                    if nmTotal_Reg_Documentos > 0 Then
                                       --actualizar  el campo SNGRANEL_NAL = 'S'
                                       --de la tabla TZFW_TRANSITOS_DOCUMENTOS  
                                       update tzfw_transitos_documentos x
                                       set    x.sngranel_nal = 'N'
                                       where  x.cdcia_usuaria     = prcrRecord.cdcia_usuaria
                                       and    x.nmdoctransporte   = prcrRecord.nmdoctransporte
                                       and    x.cdtipo_documento  = vchcdtipo_documento
                                       and    x.cdtipo_documento  = ( select ti.cdtipo_ingreso
                                                                      from   tzfw_tipos_ingreso ti
                                                                      where  ti.cdtipo_ingreso =  x.cdtipo_documento
                                                                      and    ti.nacional = 'S');
                                    end if; 
                                 end;--6
                              end if;--6 
                      end if;--5 
                end if;--4 
           end if; --3
      end if;--2   
    end if; --1  
    return;
end Update$;
-----------------------------------------------------------UpdateCntrlIngresos.prc ------------------------------------------------
procedure Insert$Auditoria(
    ircrRecord                     in       rtytzfw_archivos_dig,
    onmbId                         out      number) 
is
   onmbErr                          number;
   ovchErrMsg                       varchar2(2048);
   prcrRecordAud                    rtytzfw_archivos_dig;
   nmbId                            number(9) := 0;
   dtFecha_actual                   date;

   cursor cuValorSec_archivos_dig is
   select seq_tzfw_archivos_dig.nextval from dual;

   cursor cuFecha_actual is
   select sysdate from dual;

begin
/****************************************************************************************
    5.0        20190605    Guillermo Prieto   Modificacion del paquete para incluir los campos para el requerimiento de 
                                              optimizacion de imagenes:
                                              - RUTA_FINAL (ubicacion del archivo optimizado)
                                              - OBSERVACION (Manejo de excepciones al optimizar, como un log) 
                                              - FECHA_OPTIMIZACION (Fecha en la que es optimizado un archivo)
                                              - DURACION_OPTIMIZADO (Tiempo en que tarda completar la optimizacion de un archivo)
                                              - TAMANO_ARCHIV_ORIG
                                              - TAMANO_ARCHIV_OPTI                                              
                                              de acuerdo al documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
*****************************************************************************************/
   prcrRecordAud := ircrRecord;
   open   cuValorSec_archivos_dig;
   fetch  cuValorSec_archivos_dig into nmbId;
   close  cuValorSec_archivos_dig;

   open   cuFecha_actual;
   fetch  cuFecha_actual into dtFecha_actual;
   close  cuFecha_actual;


   INSERT INTO tzfw_archivos_dig (fmm_placa,archivo, fecha, id, vchOpe, vchModulo, cdusuario, id_source, nmtamano_archiv_orig)
   VALUES(prcrRecordAud.fmm_placa,prcrRecordAud.archivo, dtFecha_actual, nmbId,
    prcrRecordAud.vchOpe, prcrRecordAud.vchModulo, prcrRecordAud.cdusuario, prcrRecordAud.id_source, prcrRecordAud.nmtamano_archiv_orig);
    commit;
    onmbId := nmbId + 1;
    return;
exception
    when others then
        prcrErrRecord.Nmerror := sqlcode;

        prcrErrRecord.DsMensaje_bd := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
                                             instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

        if (prcrErrRecord.DsMensaje_bd is null) then
            prcrErrRecord.DsMensaje_bd := substr(sqlerrm,1,256);
        end if;

        objeto_error := substr(sqlerrm,instr(sqlerrm,'(') + 1, length(substr(sqlerrm,1,
                               instr(sqlerrm,')')-2)) - instr(sqlerrm,'(') + 1 );

        zfstzfw_admon_errores.filtrar_comillas(objeto_error,objeto_error);

        zfstzfw_admon_errores.Query$Nmerror(prcrErrRecord.Nmerror);

        if (not zfstzfw_admon_errores.SQL$$Found) then
                zfitzfw_admon_errores.Insert$(onmbErr,ovchErrMsg,prcrErrRecord);
        end if;

        onmbErr     := zfstzfw_admon_errores.Nmerror$$;

        if (zfstzfw_admon_errores.DsMensaje_Usuario$$ is null) then
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_bd$$||' '||objeto_error;
        else
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_Usuario$$||' '||objeto_error;
        end if;

        return;
end Insert$Auditoria;
-----------------------------------------------------------UpdateCntrlIngresos.prc ------------------------------------------------
procedure UpdateCntrlIngresos(
    ircrRecord                     in       rtytzfw_transitos_documentos,
    icdidentificacion              in       varchar2,
    icdusuario_ab                  in      varchar2 default null)
is
   clbValorAct clob;
   clbValorAnt clob;
   rcrRecordAnt    tzfw_transitos_documentos%rowtype;
begin
    prcrRecord := ircrRecord;

    if(prcrRecord.snrecibo = 'S') then
       prcrRecord.cdusuario_recibo := icdidentificacion;
       prcrRecord.ferecibo         := sysdate;
    else
       prcrRecord.cdusuario_recibo := null;
       prcrRecord.ferecibo := null;
    end if;

     select *
     into rcrRecordAnt
     from TZFW_TRANSITOS_DOCUMENTOS c
     where c.id = ircrRecord.id;

     clbValorAnt := rcrRecordAnt.cdplaca ||'|'||rcrRecordAnt.feingreso||'|'||rcrRecordAnt.cdcia_usuaria||'|'||
                    rcrRecordAnt.nmtransito_documento||'|'||rcrRecordAnt.cdtipo_documento||'|'||rcrRecordAnt.nmtotal_doctransporte||'|'||
                    rcrRecordAnt.nmdoctransporte||'|'||rcrRecordAnt.nmtransito||'|'||rcrRecordAnt.nmtotal_contenedor||'|'||
                    rcrRecordAnt.nmtotal_cont_x_camion||'|'||rcrRecordAnt.cdaduana||'|'||rcrRecordAnt.fedesde||'|'||
                    rcrRecordAnt.fehasta||'|'||rcrRecordAnt.cdtipo_desprecinto||'|'||rcrRecordAnt.snrecibo||'|'||
                    rcrRecordAnt.cdusuario_recibo||'|'||rcrRecordAnt.ferecibo||'|'||rcrRecordAnt.sncierre||'|'||
                    rcrRecordAnt.dscausal_operacion||'|'||rcrRecordAnt.sninconsistencia||'|'||rcrRecordAnt.id||'|'||
                    rcrRecordAnt.cdusuario_aud;

     clbValorAct := prcrRecord.cdplaca ||'|'||prcrRecord.feingreso||'|'||prcrRecord.cdcia_usuaria||'|'||
                    prcrRecord.nmtransito_documento||'|'||prcrRecord.cdtipo_documento||'|'||prcrRecord.nmtotal_doctransporte||'|'||
                    prcrRecord.nmdoctransporte||'|'||prcrRecord.nmtransito||'|'||prcrRecord.nmtotal_contenedor||'|'||
                    prcrRecord.nmtotal_cont_x_camion||'|'||prcrRecord.cdaduana||'|'||prcrRecord.fedesde||'|'||
                    prcrRecord.fehasta||'|'||prcrRecord.cdtipo_desprecinto||'|'||prcrRecord.snrecibo||'|'||
                    prcrRecord.cdusuario_recibo||'|'||prcrRecord.ferecibo||'|'||prcrRecord.sncierre||'|'||
                    prcrRecord.dscausal_operacion||'|'||prcrRecord.sninconsistencia||'|'||prcrRecord.id||'|'||
                    prcrRecord.cdusuario_aud;

    UPDATE TZFW_TRANSITOS_DOCUMENTOS
       SET  snrecibo = prcrRecord.snrecibo,
            ferecibo = prcrRecord.ferecibo,
            cdusuario_recibo = prcrRecord.cdusuario_recibo
    WHERE   id= prcrRecord.id;
    sqlsuccess := sql%rowcount > 0;

    zfstzfw_auditoria_ope.Insert$('TZFW_TRANSITOS_DOCUMENTOS','U',icdusuario_ab,clbValorAct,clbValorAnt);

    return;
end UpdateCntrlIngresos;
-----------------------------------------------------------UpdateCntrlIngresos.prc ------------------------------------------------
procedure UpdateAutoriza(
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,
    ircrRecord                     in       rtytzfw_transitos_documentos)
is
    vchPlaca        tzfw_audit_planilla.cdplaca%type;
    vchCia          tzfw_audit_planilla.cdcia_usuaria%type;
    dtfecha         tzfw_audit_planilla.feingreso%type;
    nmbTotal        number;
begin
    prcrRecord := ircrRecord;
    select cdcia_usuaria,cdplaca,feingreso
    into vchCia,vchPlaca,dtfecha
    from TZFW_TRANSITOS_DOCUMENTOS
    where id = prcrRecord.id;
    
    select count(1)
    into nmbTotal
    from tzfw_audit_planilla
    where cdcia_usuaria=vchCia
    and cdplaca= vchPlaca
    and feingreso=dtfecha
    and (cdvalor_actual ='T' or cdvalor_anterior='T');
  
    -- de ser asi no debe modificarse el campo tipo desprecinte y comentarios del desprecinte
    if nmbTotal > 0 then        
        UPDATE TZFW_TRANSITOS_DOCUMENTOS
           SET  snautoriza = prcrRecord.Snautoriza,
                feautoriza = sysdate,
                cdusuario_autoriza = prcrRecord.Cdusuario_Autoriza                
        WHERE   id= prcrRecord.id;
    else
        UPDATE TZFW_TRANSITOS_DOCUMENTOS
        SET  snautoriza = prcrRecord.Snautoriza,
            feautoriza = sysdate,
            cdusuario_autoriza = prcrRecord.Cdusuario_Autoriza
        WHERE   id= prcrRecord.id;
        
        -- se valida si existe algun transito sin autorizar
        select count(1)
        into nmbTotal
        from TZFW_TRANSITOS_DOCUMENTOS, tzfw_parametros
        where cdplaca= vchPlaca
        and feingreso=dtfecha
        and nvl(snautoriza,'N') = 'S'
        and instr(dsvalor,cdtipo_documento)> 0
        and DSPARAMETRO = 'TRANSITO';
   dbms_output.put_line(nmbTotal);       
        if nmbTotal = 0 then
            UPDATE TZFW_camiones
            SET  CDTIPODESPRECINTE = null,
                DSCOMENTARIODESPRE = null
            WHERE  cdplaca= vchPlaca
            and feingreso=dtfecha;
        end if;
        
    end if;
    
    sqlsuccess := sql%rowcount > 0;

    return;
exception
  when others then
    onmbError := sqlcode;
    ovchMessaje := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
        instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

end UpdateAutoriza;
----------------------------------------------------------- Delete$.prc -----------------------------------------------
procedure Delete$(
    ircrRecord                      in      rtytzfw_transitos_documentos)
is

    vchcdplaca                       TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type;
    vchcdcia_usuaria                 TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type;
    vfeingreso                       TZFW_TRANSITOS_DOCUMENTOS.FEINGRESO%type;
    Vnmtransito_Documento            TZFW_TRANSITOS_DOCUMENTOS.NMTRANSITO_DOCUMENTO%type;
    vchTipo                          TZFW_camiones.cdtipodesprecinte%type;      
    vchComentario                    TZFW_camiones.dscomentariodespre%type;      
    VERROR                          VARCHAR2(2000);

begin

    BEGIN

        SELECT t.CDPLACA,CDCIA_USUARIA,t.FEINGRESO,NMTRANSITO_DOCUMENTO,cdtipodesprecinte,dscomentariodespre
        INTO VCHCDPLACA,VCHCDCIA_USUARIA,VFEINGRESO,VNMTRANSITO_DOCUMENTO, vchTipo, vchComentario
        FROM TZFW_TRANSITOS_DOCUMENTOS t, tzfw_camiones t1
        WHERE t.ID =IRCRRECORD.ID
        and t.cdplaca = t1.cdplaca
        and t.feingreso = t1.feingreso;

        --ELIMINA EL REGISTRO DE LA TABLA TZFW_PATHCIA_X_PLACA
        DELETE TZFW_PATHCIA_X_PLACA
        WHERE CDPLACA=VCHCDPLACA AND CDCIA_USUARIA=VCHCDCIA_USUARIA
        AND FEINGRESO=VFEINGRESO AND NMTRANSITO_DOCUMENTO=VNMTRANSITO_DOCUMENTO;

        DELETE TZFW_PATHCIA_X_PLACA_ERI
        WHERE CDPLACA=VCHCDPLACA AND CDCIA_USUARIA=VCHCDCIA_USUARIA
        AND FEINGRESO=VFEINGRESO AND NMTRANSITO_DOCUMENTO=VNMTRANSITO_DOCUMENTO;

        delete from tzfw_estados_planilla
        where CDPLACA=VCHCDPLACA AND CDCIA_USUARIA=VCHCDCIA_USUARIA
        AND FEINGRESO=VFEINGRESO AND NMTRANSITO_DOCUMENTO=VNMTRANSITO_DOCUMENTO;

        delete from tzfw_audit_planilla
        where CDPLACA=VCHCDPLACA AND CDCIA_USUARIA=VCHCDCIA_USUARIA
        AND FEINGRESO=VFEINGRESO AND NMTRANSITO_DOCUMENTO=VNMTRANSITO_DOCUMENTO;

    EXCEPTION WHEN NO_DATA_FOUND then
            null;
    END;
    prcrRecord := ircrRecord;
    
    -- mirsan consulta si el registro a eliminar tiene el tipo de desprecinte    
    
    if vchTipo is not null then
        -- actualiza otro registro asociado a la placa y que sea transito con los datos del tipo de desprecinte, ya que alguno debe tenerlos
        update TZFW_camiones
        set cdtipodesprecinte = vchTipo,
            dscomentariodespre = vchComentario
        where cdplaca = VCHCDPLACA
        and feingreso =vfeingreso;
    end if;
    
    DELETE TZFW_TRANSITOS_DOCUMENTOS
    WHERE  ID = prcrRecord.id;

    sqlsuccess := sql%rowcount > 0;
    return;
end Delete$;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure XQuery(
    oclbXML                         out     clob)
is
    vchXQuery                       varchar2(1024);
begin
    vchXQuery := 'select '
              || 'm.* '
              || 'from   TZFW_TRANSITOS_DOCUMENTOS m';
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XQuery;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure XQuery$Id(
    oclbXML                         out     clob)
is
    vchXQuery                       varchar2(1024);
begin
    vchXQuery := 'select '
              || 'm.* '
              || 'from   TZFW_TRANSITOS_DOCUMENTOS m'
              ||' where CDPLACA ='''||prcrRecord.Cdplaca||''''
             -- ||' and feingreso = to_date('''||prcrRecord.Feingreso||',''yyyy-mm-dd hh24:mi:ss'') '
              ||' and cdcia_usuaria ='''||prcrRecord.Cdcia_Usuaria||''''
              ||' and nmtransito_documento ='||prcrRecord.Nmtransito_Documento;
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XQuery$Id;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure XQueryAutoriza(
    ivchCiaUsuaria     in  tzfw_formularios.cdcia_usuaria%type,
    ivchPlaca          in  tzfw_transitos_documentos.cdplaca%type,
    idtFeIngreso       in  varchar2,
    oclbXML            out     clob)
is
    vchXQuery                       varchar2(1024);
    total                           number;
    noAutorizado                    number;
    nmbfinal                        number :=1;
begin
  select count(1)
  into total
  from tzfw_transitos_documentos
  where cdcia_usuaria =ivchCiaUsuaria
  and cdplaca = ivchPlaca
  and feingreso = to_date(idtFeIngreso,'dd/mm/yyyy hh24:mi:ss');

   select count(1)
   into noAutorizado
   from tzfw_transitos_documentos
   where cdcia_usuaria =ivchCiaUsuaria
   and cdplaca = ivchPlaca
   and nvl(snautoriza,'N') = 'N'
   and feingreso = to_date(idtFeIngreso,'dd/mm/yyyy hh24:mi:ss');

  if (total = 0) then
    nmbFinal := -1;
  else
    if noAutorizado = 0 then
      nmbFinal := 0;
    end if;
  end if;

  vchXQuery := ' select '||nmbfinal||' total '
            || ' from   dual ';
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XQueryAutoriza;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure XQueryAutorizaDoc(
    ivchCiaUsuaria     in  tzfw_formularios.cdcia_usuaria%type,
    ivchPlaca          in  tzfw_transitos_documentos.cdplaca%type,
    idtFeIngreso       in  varchar2,
    inmbTransito       in  tzfw_transitos_documentos.nmtransito_documento%type,
    oclbXML            out     clob)
is
    vchXQuery                       varchar2(1024);
    total                           number;
begin
  select count(1)
  into total
  from tzfw_transitos_documentos
  where cdcia_usuaria =ivchCiaUsuaria
  and cdplaca = ivchPlaca
  and feingreso = to_date(idtFeIngreso,'dd/mm/yyyy hh24:mi:ss')
  and NMTRANSITO_DOCUMENTO = inmbTransito
   and nvl(snautoriza,'N') = 'N';



  vchXQuery := ' select '||total||' total '
            || ' from   dual ';
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XQueryAutorizaDoc;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure XQueryDigitalizacion(
    ivchCiaUsuaria     in  tzfw_formularios.cdcia_usuaria%type,
    ivchPlaca          in  tzfw_transitos_documentos.cdplaca%type,
    idtFeIngreso       in  varchar2,
    inmbTransito       in  tzfw_transitos_documentos.nmtransito_documento%type,
    oclbXML            out     clob)
is
    vchXQuery                       varchar2(1024);
    total                           number;
begin
  select count(1)
  into total
  from tzfw_transitos_documentos
  where cdcia_usuaria =ivchCiaUsuaria
  and cdplaca = ivchPlaca
  and feingreso = to_date(idtFeIngreso,'dd/mm/yyyy hh24:mi:ss')
  and NMTRANSITO_DOCUMENTO = inmbTransito
  and FEDIGITALIZACIONeri is null;

  if (total > 0) then
      vchXQuery := ' select ''N'' DIGITALIZACION from   dual ';
  else
      vchXQuery := ' select ''S'' DIGITALIZACION from   dual ';
  end if;

  oclbXML := dbms_xmlgen.getXML(vchXQuery);
  return;
end XQueryDigitalizacion;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure XQueryEstado(
    icdcia_usuaria                  in      tzfw_transitos_documentos.cdcia_usuaria%type,
    icdplaca                        in      tzfw_transitos_documentos.cdplaca%type,
    idtFEINGRESO                    in      varchar2,
    oclbXML                         out     clob)
is
    vchXQuery                       varchar2(1024);
    total                           number;
    totalp                          number;
begin

  select count(1)
  into totalp
  from tzfw_estados_planilla t1
  where T1.CDCIA_USUARIA =icdcia_usuaria
  and   t1.CDPLACA =icdplaca
  and   t1.feingreso = to_date(idtFEINGRESO ,'yyyy-mm-dd hh24:mi:ss')
  and t1.cdestado ='P';

  if (totalp > 0) then
    vchXQuery := 'select 0 total'
              || ' from   dual  ';
else
    vchXQuery := 'select count(1) total'
              || ' from   tzfw_estados_planilla t1'
              || ' where T1.CDCIA_USUARIA ='''||icdcia_usuaria||''' '
              ||' and   t1.CDPLACA = ''' || icdplaca || ''' '
              ||' and   t1.feingreso = to_date(''' || idtFEINGRESO || ''',''yyyy-mm-dd hh24:mi:ss'')'
             ||' and t1.cdestado in(''E'',''T'',''N'',''R'',''C'',''S'')   ';
end if;

    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XQueryEstado;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure XQueryImagenesXPlaca(
    icdplaca                        in      tzfw_transitos_documentos.cdplaca%type,
    idtFEINGRESO                    in      varchar2,
    oclbXML                         out     clob)
is
    vchXQuery                       varchar2(1024);
begin

    vchXQuery := 'select DSRUTA, ''ERI'' origen '||
               ' from tzfw_pathcia_x_placa_eri ' ||
               ' where cdplaca=''' || icdplaca || ''' '||
               ' and feingreso =to_date(''' || idtFEINGRESO || ''',''yyyy-mm-dd hh24:mi:ss'')'||
               ' union all '||
               ' select DSRUTA, ''UCC'' origen '||
               ' from tzfw_pathcia_x_placa_ucc ' ||
               ' where cdplaca=''' || icdplaca || ''' '||
               ' and feingreso =to_date(''' || idtFEINGRESO || ''',''yyyy-mm-dd hh24:mi:ss'')'||
               ' union all '||
               ' select DSRUTA, ''SFRA'' origen '||
               ' from tzfw_pathcia_x_placa_sfra ' ||
               ' where cdplaca=''' || icdplaca || ''' '||
               ' and feingreso =to_date(''' || idtFEINGRESO || ''',''yyyy-mm-dd hh24:mi:ss'')';

    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XQueryImagenesXPlaca;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure XQuerySalidas(
        ivchPlaca                       in  tzfw_transitos_documentos.cdplaca%type,
        idtFeIngreso                    in  varchar2,
        oclbXML                         out     clob)
is
    vchXQuery                       varchar2(1024);
begin

        vchXQuery := ' select t3.id, t1.cdcia_usuaria, t2.dscia_usuaria,t4.dstipo_ingreso, nvl(t3.nmdoctransporte, t3.nmtransito) doc,NMTRANSITO_DOCUMENTO '
                 ||' from tzfw_camiones t, tzfw_cias_x_camion t1, tzfw_cia_usuarias t2, tzfw_transitos_documentos t3, tzfw_tipos_ingreso t4 '
                 ||' where t.cdplaca =''' || ivchPlaca || ''' '
                 ||' and t.feingreso =to_date(''' || idtFeIngreso || ''',''yyyy-mm-dd hh24:mi:ss'')'
                 ||' and t.cdplaca = t1.cdplaca '
                 ||' and t.feingreso = t1.feingreso '
                 ||' and t1.cdcia_usuaria = t2.cdcia_usuaria '
                 ||' and t1.cdplaca = t3.cdplaca '
                 ||' and t1.feingreso = t3.feingreso '
                 ||' and t1.cdcia_usuaria = t3.cdcia_usuaria '
                 ||' and t3.cdtipo_documento = t4.cdtipo_ingreso ';

    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XQuerySalidas;
------------------------------------------------------XQuery-----------------------------------------------------------
procedure Query$ControlTiempo(
    ivchFormulario                  in tzfw_formularios.nmformulario_zf%type,
    ivchPlaca                       in tzfw_transitos_documentos.cdplaca%type,
    ivchCia                         in tzfw_transitos_documentos.cdcia_usuaria%type,
    oclbXML                         out     clob)
is
    vchXQuery                       varchar2(1024);
    vchValor                        varchar(50);
begin
  select ''''||replace(dsvalor,' ',''',''')||''''
  into vchValor
  from tzfw_parametros
  where dsParametro ='OTROS_INGRESOS';

    vchXQuery := 'select nvl(SNPARCIAL,''N'')snparcial '
              ||' from tzfw_transitos_documentos t '
              ||' where t.nmdoctransporte is not null '
              ||' and t.cdtipo_documento in('||vchValor||') '
              ||' and t.nmdoctransporte = '''|| ivchFormulario||''''
              ||' and t.cdplaca != '''|| ivchPlaca||''''
              ||' and t.cdcia_usuaria = '''|| ivchCia||''''
              ||' and feingreso = (select min(feIngreso) from tzfw_transitos_documentos t1 '
              || ' where t1.nmdoctransporte = t.nmdoctransporte '
              ||' and t1.cdcia_usuaria = t.cdcia_usuaria) ' ;
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end Query$ControlTiempo;
---------------------------------------------------------------------------------------------------------------------------
function fvchBloqueados(ivchCondicion  in varchar2)
return clob
is
    vchXQuery clob;
    CONTROLBASCULA  tzfw_parametros.dsvalor%type;
    INICIOTIEMPO    tzfw_parametros.dsvalor%type;
    FECHAPRODUCCION  tzfw_parametros.dsvalor%type;
    VENCIMIENTOS_TEMPORALES tzfw_parametros.dsvalor%type;
begin
  -- control de ingresos
     begin
      select dsvalor into FECHAPRODUCCION from tzfw_parametros where dsParametro='FECHA_PRODUCCION';
    exception
      when no_data_found then
      FECHAPRODUCCION:=null;
    end;

    begin
      select dsvalor into VENCIMIENTOS_TEMPORALES from tzfw_parametros where dsParametro='VENCIMIENTO_TEMPORALES';
    exception
      when no_data_found then
      VENCIMIENTOS_TEMPORALES:=0;
    end;

     begin
      select dsvalor into CONTROLBASCULA from tzfw_parametros where dsParametro='CONTROLBASCULA';
      exception
        when no_data_found then
        CONTROLBASCULA:='1';
      end;

       begin
        select dsvalor into INICIOTIEMPO from tzfw_parametros where dsParametro='INICIOTIEMPO';
      exception
        when no_data_found then
        INICIOTIEMPO:='PRIMERCAMION';
      end;

vchXQuery := '
 tmp as(
 select t.cdplaca, t.nmtransito_documento, t.id, nvl(t.nmdoctransporte,t.nmtransito) doc, ''P'' tipo ,
        sngranvolumen  ,planilla_recepcion,c.ndias_planilla, t.cdcia_usuaria , t.feingreso, ca.febascula,
        c.nhoras_planilla, c.NMCONTROL_HORA , c.NDIAS_FMM_ING ,t.nmdoctransporte, snbloqueo, t.nmtransito,
        sysdate feestado, '' '' snparcial,'' '' nmformulario_zf
 from TZFW_TRANSITOS_DOCUMENTOS t,  TZFW_CIA_USUARIAS c,  TZFW_CAMIONES ca, tzfw_tipos_ingreso j
 where t.cdcia_usuaria = c.cdcia_usuaria
 and t.cdtipo_documento is not null
 and t.cdplaca = ca.cdplaca
 and t.cdtipo_documento = j.cdtipo_ingreso
 and t.feingreso = ca.feingreso
 and nvl(t.snrecibo,''N'') =''N''
 and ca.febascula is not null
 and trunc(ca.febascula) > to_date('''||FECHAPRODUCCION||''',''dd/mm/yyyy'')
 and ca.sningresa_carga = ''S'''||replace(ivchCondicion ,'CH.CDCIA_USUARIA','c.cdcia_usuaria')
||' union all
select t.cdplaca, t.nmtransito_documento, t.id, nvl(t.nmdoctransporte,t.nmtransito) doc, ''F'' tipo ,
     sngranvolumen  ,f0.planilla_recepcion,c.ndias_planilla, t.cdcia_usuaria , t.feingreso, ca.febascula,
     c.nhoras_planilla, c.NMCONTROL_HORA , c.NDIAS_FMM_ING ,t.nmdoctransporte, snbloqueo, t.nmtransito,FEESTADO,
     d.snparcial, nmformulario_zf
from TZFW_TRANSITOS_DOCUMENTOS t,  TZFW_CIA_USUARIAS c,  TZFW_CAMIONES ca , tzfw_documentos_x_cia d, tzfw_estados_planilla p, tzfw_tipos_ingreso f0
where t.cdcia_usuaria = c.cdcia_usuaria  and t.cdtipo_documento is not null
and t.cdplaca = ca.cdplaca  and t.feingreso = ca.feingreso
and ca.febascula is not null
and trunc(ca.febascula) > to_date('''||FECHAPRODUCCION||''',''dd/mm/yyyy'')
and ca.sningresa_carga = ''S''
and t.cdplaca =d.cdplaca
and t.feingreso = d.feingreso
and t.cdcia_usuaria = d.cdcia_usuaria
and t.nmtransito_documento = d.nmtransito_documento
and d.cdplaca = p.cdplaca
and d.feingreso = p.feingreso
and d.cdcia_usuaria = p.cdcia_usuaria
and t.CDTIPO_DOCUMENTO = f0.cdtipo_ingreso
and d.nmtransito_documento = p.nmtransito_documento
and p.cdestado =''C''
and nvl(d.snrecibo,''N'') =''N''
and d.nmconsecutivo_doc = p.nmconsecutivo_doc    '||replace(ivchCondicion,'CH.CDCIA_USUARIA','c.cdcia_usuaria')
||' ),
fecha as(
select t0.cdplaca, t0.feingreso,t0.nmtransito_documento,t0.cdcia_usuaria, decode('''||INICIOTIEMPO  ||''',''PRIMERCAMION'',
       min(decode('''||CONTROLBASCULA||''',1,(select min(t00.febascula)
                                                              from tmp t00, tzfw_camiones t1
                                                              where t00.doc=t0.doc
                                                              and   t00.cdplaca = t1.cdplaca
                                                              and t00.feingreso = t1.feingreso),
                                                            (select min(t1.feauditoria)
                                                              from tmp t00, tzfw_audit_planilla t1
                                                              where t00.doc=t0.doc
                                                              and   t00.cdplaca = t1.cdplaca
                                                              and t00.cdcia_usuaria = t1.cdcia_usuaria
                                                              and t00.feingreso = t1.feingreso
                                                              and t00.nmtransito_documento = t1.nmtransito_documento
                                                              and t1.cdvalor_actual in(''N'',''E'',''T'')))),''ULTIMOCAMION'',
       max(decode('''||CONTROLBASCULA||''',1,(select max(t00.febascula)
                                                              from tmp t00, tzfw_camiones t1
                                                              where t00.doc=t0.doc
                                                              and   t00.cdplaca = t1.cdplaca
                                                              and t00.feingreso = t1.feingreso),
                                              (select max(t1.feauditoria)
                                                from tmp t00, tzfw_audit_planilla t1
                                                where t00.doc=t0.doc
                                                and   t00.cdplaca = t1.cdplaca
                                                and t00.cdcia_usuaria = t1.cdcia_usuaria
                                                and t00.feingreso = t1.feingreso
                                                and t00.nmtransito_documento = t1.nmtransito_documento
                                                              and t1.cdvalor_actual in(''N'',''E'',''T''))))) fechaReferencia
from tmp t0
group by t0.cdplaca, t0.feingreso, t0.nmtransito_documento,t0.cdcia_usuaria),
documentos as(
select t.cdplaca, t.feingreso, t.cdcia_usuaria, t.nmtransito_documento, count(1) total
from tmp t, tzfw_documentos_x_cia j
where j.cdplaca = t.cdplaca
and j.feingreso = t.feingreso
and j.cdcia_usuaria = t.cdcia_usuaria
and j.nmtransito_documento = t.nmtransito_documento
and j.snparcial=''S''
group by t.cdplaca, t.feingreso, t.cdcia_usuaria, t.nmtransito_documento),
tmpfinal as(
select a.cdplaca, a.feingreso, a.cdcia_usuaria, a.nmdoctransporte,a.febascula,snbloqueo,nmtransito,
       case when (sngranvolumen =''S'' and planilla_recepcion =''S'' and nvl(ndias_planilla,0) !=0)  then
            (fechaReferencia + ndias_planilla)
       when (sngranvolumen =''N'' and planilla_recepcion =''S'') then fechaReferencia  + nhoras_planilla/24
       when total > 0 then (fechaReferencia  + NDIAS_FMM_ING)
       when planilla_recepcion =''N'' then  (fechaReferencia  + NMCONTROL_HORA/24)
       else (fechaReferencia  + nhoras_planilla/24) end fecha_Vencimiento,
       case when (sngranvolumen =''S'' and planilla_recepcion =''S'' and nvl(ndias_planilla,0) !=0) then ''DIAS''
            when (sngranvolumen =''N'' and planilla_recepcion =''S'') then ''HORAS''
            when total> 0 then ''DIAS''
            when planilla_recepcion =''N'' then ''HORAS'' else ''HORAS'' end  CONTROL_TIEMPO,
       case when (sngranvolumen =''S'' and planilla_recepcion =''S'' and nvl(ndias_planilla,0) !=0)  then ndias_planilla
            when (sngranvolumen =''N'' and planilla_recepcion =''S'' ) then nhoras_planilla/24
            when total> 0 then NDIAS_FMM_ING
            when planilla_recepcion =''N'' then NMCONTROL_HORA/24
            else nhoras_planilla/24 end valor,
       tipo , fechareferencia, doc
from tmp a, fecha b , documentos c
where a.cdplaca = b.cdplaca
and a.feingreso = b.feingreso
and a.nmtransito_documento = b.nmtransito_documento
and a.cdcia_usuaria = b.cdcia_usuaria
and tipo=''P''
and a.cdplaca = c.cdplaca(+)
and a.feingreso = c.feingreso(+)
and a.nmtransito_documento = c.nmtransito_documento(+)
and a.cdcia_usuaria = c.cdcia_usuaria(+)
and (nhoras_planilla != 0 or NMCONTROL_HORA !=0 or NDIAS_FMM_ING !=0 or ndias_planilla !=0)
union all
select a.cdplaca, a.feingreso, a.cdcia_usuaria, a.nmdoctransporte,a.febascula,snbloqueo,nmtransito,
       case when (nvl(PLANILLA_RECEPCION,''N'') =''S'') then FEESTADO + NMCONTROL_HORA/24
            when (snparcial =''S'' and '''||CONTROLBASCULA||'''=''1'' and nvl(NDIAS_FMM_ING,0) != 0) then FEESTADO + NDIAS_FMM_ING
            when (snparcial =''S'' and '''||CONTROLBASCULA||'''=''0'' and nvl(NDIAS_FMM_ING,0) != 0) then FEESTADO + NDIAS_FMM_ING
            when (nvl(snparcial,''N'') =''N'' and '''||CONTROLBASCULA||'''=''1'' and nvl(NMCONTROL_HORA,0) !=0) then  FEESTADO + NMCONTROL_HORA/24
            when (nvl(snparcial,''N'') =''N'' and '''||CONTROLBASCULA||'''=''0'' and nvl(NMCONTROL_HORA,0) !=0) then  FEESTADO + NMCONTROL_HORA/24
       end fechaVencimiento,
       case when (nvl(PLANILLA_RECEPCION,''N'') =''S'') then ''HORAS''
            when (snparcial =''S'' and '''||CONTROLBASCULA||'''=''1'' and nvl(NDIAS_FMM_ING,0) != 0) then ''DIAS''
            when (snparcial =''S'' and '''||CONTROLBASCULA||'''=''0'' and nvl(NDIAS_FMM_ING,0) != 0) then ''DIAS''
           when (nvl(snparcial,''N'') =''N'' and '''||CONTROLBASCULA||'''=''1'' and nvl(NMCONTROL_HORA,0) !=0) then ''HORAS''
           when (nvl(snparcial,''N'') =''N'' and '''||CONTROLBASCULA||'''=''0'' and nvl(NMCONTROL_HORA,0) !=0) then ''HORAS''
       end CONTROL_TIEMPO,
       case  when (snparcial =''S'' and '''||CONTROLBASCULA||'''=''1'' and nvl(NDIAS_FMM_ING,0) != 0) then NDIAS_FMM_ING
             when (snparcial =''S'' and '''||CONTROLBASCULA||'''=''0'' and nvl(NDIAS_FMM_ING,0) != 0) then NDIAS_FMM_ING
             when (nvl(snparcial,''N'') =''N'' and '''||CONTROLBASCULA||'''=''1'' and nvl(NMCONTROL_HORA,0) !=0) then NMCONTROL_HORA/24
             when (nvl(snparcial,''N'') =''N'' and '''||CONTROLBASCULA||'''=''0'' and nvl(NMCONTROL_HORA,0) !=0) then NMCONTROL_HORA/24
       end valor,
       tipo , fechareferencia, nmformulario_zf NMDOCTRANSPORTE
from tmp a, fecha b , documentos c
where a.cdplaca = b.cdplaca
and a.feingreso = b.feingreso
and a.nmtransito_documento = b.nmtransito_documento
and a.cdcia_usuaria = b.cdcia_usuaria
and tipo=''F''
and a.cdplaca = c.cdplaca(+)
and a.feingreso = c.feingreso(+)
and a.nmtransito_documento = c.nmtransito_documento(+)
and a.cdcia_usuaria = c.cdcia_usuaria(+)
and (nhoras_planilla != 0 or NMCONTROL_HORA !=0 or NDIAS_FMM_ING !=0 or ndias_planilla !=0))
select cdplaca,'' '' feingreso,'' '' CDCIA_USUARIA,nvl(doc,'' '') NMTRANSITO, fecha_vencimiento, ''N'' SNBLOQUEADO,doc,
case when abs(sysdate-fechaReferencia) <= 1then
     to_char(round((sysdate-fechaReferencia)*24,2))||'' HORAS ''
else
    to_char(round(sysdate-fechaReferencia,2))||'' DIAS''
end tiempo,
case when fecha_vencimiento< sysdate then ''-1''
     when (sysdate between fecha_vencimiento-valor/2 and fecha_vencimiento) then ''0''
     else ''1'' end tipo,
case when (fecha_vencimiento-sysdate) between 0 and -1 then  to_char(round((fecha_vencimiento-sysdate)*24,2))||'' HORAS''
     when (fecha_vencimiento-sysdate) <-1 then to_char(round((fecha_vencimiento-sysdate),2))||'' DIAS''
     when abs(fecha_vencimiento -sysdate) <=1 then to_char(round((fecha_vencimiento -sysdate)*24,2))||'' HORAS''
     else to_char(round((fecha_vencimiento -sysdate),2))||'' DIAS'' end tiempofaltante, control_tiempo
from tmpfinal ';
if VENCIMIENTOS_TEMPORALES !='0' then
vchXQuery := vchXQuery||' where fecha_vencimiento-'||VENCIMIENTOS_TEMPORALES||'<=sysdate ';
end if;
vchXQuery := vchXQuery||' union all select * from tmp1';

return vchXQuery;
end fvchBloqueados;
------------------------------------------------------XControlIngresos.prc-----------------------------------------------------------
procedure XControlIngresos(
    ivchFilter      in varchar2,
    IvchFilter2     in varchar2,
    ivchVencimiento in varchar2,
    inmbRegistros   in number,
    inmbLimite      in number,
    oclbXML         out clob)
is
    vchFilter       varchar2(1024);
    vchFilter2       varchar2(1024);
    vchFilter3       varchar2(1024);
    vchVencimiento   varchar2(1024);
    nmbLimite       number;
    vchXQuery       clob;
    vchControl      varchar2(2000);
    CONTROLBASCULA  tzfw_parametros.dsvalor%type;
    INICIOTIEMPO    tzfw_parametros.dsvalor%type;
    FECHAPRODUCCION tzfw_parametros.dsvalor%type;
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
function CondicionFiltro$
return varchar2
is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;

--------------------------------------------------CondicionFiltro2$-----------------------------------------------------
function CondicionFiltro3$
return varchar2
is
    begin
        vchFilter3 := replace(vchFilter3,'?','''');
        vchFilter3 := replace(vchFilter3,'[','<');
        vchXQuery := null;
        if (vchFilter3 is null) then return(vchXQuery); end if;
        return(vchFilter3);
    end CondicionFiltro3$;
--=====================================================================================================================
begin
        vchFilter := ivchFilter;
        vchFilter2 := ivchFilter;
        vchVencimiento := replace(ivchVencimiento,'?','''');
        vchVencimiento := replace(vchVencimiento,'[','<');
        vchFilter3 := SUBSTR(IvchFilter2, 4);
        nmbLimite := inmbRegistros + inmbLimite;

        begin
          select dsvalor into CONTROLBASCULA from tzfw_parametros where dsParametro='CONTROLBASCULA';
        exception
          when no_data_found then
          CONTROLBASCULA:='1';
        end;

         begin
          select dsvalor into INICIOTIEMPO from tzfw_parametros where dsParametro='INICIOTIEMPO';
        exception
          when no_data_found then
          INICIOTIEMPO:='PRIMERCAMION';
        end;

        begin
          select dsvalor into FECHAPRODUCCION from tzfw_parametros where dsParametro='FECHA_PRODUCCION';
        exception
          when no_data_found then
          FECHAPRODUCCION:=null;
        end;



        vchXQuery := 'select b.*,rownum as nreg from (select nvl(to_char(fechaReferencia,''yyyy-mm-dd hh24:mi:ss''),'' '') fecha_vencimiento,a.* from (
        with tmp as
          (
            select t.cdplaca, t.feingreso fingreso, to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') FECHA_REGISTRO ,
                   t.cdcia_usuaria, c.dscia_usuaria, to_char(t.nmtransito_documento) nmtransito_documento, nvl(t.cdtipo_documento,'' '') cdtipo_documento,
                   j.dstipo_ingreso dstipo_documento, nvl(to_char(t.nmtotal_doctransporte),''0'') nmtotal_doctransporte,
                   nvl(t.nmdoctransporte, '' '') nmdoctransporte, nvl(t.nmtransito , '' '') nmtransito, nvl(to_char(t.nmtotal_contenedor),0) nmtotal_contenedor,
                   nvl(to_char(t.nmtotal_cont_x_camion ),0) nmtotal_cont_x_camion, nvl(t.snrecibo,''N'') snrecibo,
                   decode(t.snrecibo ,''N'',''NO'',''S'',''SI'',''NO'') dsrecibo, nvl(t.cdusuario_recibo, '' '') cdusuario_recibo,
                   nvl(to_char(t.ferecibo,''yyyy-mm-dd hh24:mi:ss''),'' '') ferecibo, t.sncierre, t.id, ca.febascula, nhoras_planilla,NMCONTROL_HORA, planilla_recepcion,
                   NDIAS_FMM_ING,ndias_planilla,sngranvolumen,SNPROPIOS_MEDIOS,''P'' tipo, sysdate FEESTADO,'' '' snparcial, to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso,
                   nvl(t.nmdoctransporte,t.nmtransito) doc,to_char(ca.fesalida,''yyyy-mm-dd hh24:mi:ss'') FESALIDA
            from TZFW_TRANSITOS_DOCUMENTOS t,  TZFW_CIA_USUARIAS c,  TZFW_CAMIONES ca, tzfw_tipos_ingreso j
                      where t.cdcia_usuaria = c.cdcia_usuaria
                      and t.cdtipo_documento is not null
                      and t.cdtipo_documento = j.cdtipo_ingreso
                      and t.cdplaca = ca.cdplaca
                      and t.feingreso = ca.feingreso
                      and ca.febascula is not null
                      and ca.sningresa_carga = ''S'' '||CondicionFiltro$
          ||' union all
           select t.cdplaca, t.feingreso fingreso, to_char(p.feestado,''yyyy-mm-dd hh24:mi:ss'') FECHA_REGISTRO ,
                   t.cdcia_usuaria, c.dscia_usuaria, to_char(t.nmtransito_documento) nmtransito_documento, ''F'' cdtipo_documento,
                    ''FORMULARIO'' dstipo_documento, nvl(to_char(t.nmtotal_doctransporte),''0'') nmtotal_doctransporte,
                   d.nmformulario_zf nmdoctransporte, nvl(t.nmtransito , '' '') nmtransito, '' '' nmtotal_contenedor,
                   '' '' nmtotal_cont_x_camion, nvl(d.snrecibo,''N'') snrecibo,
                   decode(d.snrecibo ,''N'',''NO'',''S'',''SI'',''NO'') dsrecibo, nvl(d.cdusuario_recibo, '' '') cdusuario_recibo,
                   nvl(to_char(d.ferecibo,''yyyy-mm-dd hh24:mi:ss''),'' '') ferecibo, '' '' sncierre, d.id, ca.febascula, nhoras_planilla,NMCONTROL_HORA, f0.planilla_recepcion,
                   NDIAS_FMM_ING,ndias_planilla,sngranvolumen,SNPROPIOS_MEDIOS,''F'' tipo, p.FEESTADO, d.snparcial,to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso,
                   nvl(t.nmdoctransporte,t.nmtransito) doc,to_char(ca.fesalida,''yyyy-mm-dd hh24:mi:ss'') FESALIDA
          from TZFW_TRANSITOS_DOCUMENTOS t,  TZFW_CIA_USUARIAS c,  TZFW_CAMIONES ca , tzfw_documentos_x_cia d, tzfw_estados_planilla p, tzfw_tipos_ingreso f0
                      where t.cdcia_usuaria = c.cdcia_usuaria  and t.cdtipo_documento is not null
                      and t.cdplaca = ca.cdplaca  and t.feingreso = ca.feingreso
                      and ca.febascula is not null
                      and ca.sningresa_carga = ''S''
                      and t.cdplaca =d.cdplaca
                      and t.feingreso = d.feingreso
                      and t.cdcia_usuaria = d.cdcia_usuaria
                      and t.nmtransito_documento = d.nmtransito_documento
                      and d.cdplaca = p.cdplaca
                      and d.feingreso = p.feingreso
                      and d.cdcia_usuaria = p.cdcia_usuaria
                      and d.nmtransito_documento = p.nmtransito_documento
                      and t.CDTIPO_DOCUMENTO = f0.cdtipo_ingreso
                      and p.cdestado =''C''
                      and d.nmconsecutivo_doc = p.nmconsecutivo_doc '||replace(replace(CondicionFiltro$,'T.NMDOCTRANSPORTE','d.nmformulario_zf'),'T.SNRECIBO','d.SNRECIBO')
          ||' ),
          fecha as(
              select t0.cdplaca, t0.feingreso,t0.nmtransito_documento,t0.cdcia_usuaria, decode('''||INICIOTIEMPO||''',''PRIMERCAMION'',
                     min(decode('''||CONTROLBASCULA||''',1,(select min(t00.febascula)
                                                              from tmp t00, tzfw_camiones t1
                                                              where t00.doc=t0.doc
                                                              and   t00.cdplaca = t1.cdplaca
                                                              and t00.fingreso = t1.feingreso),
                                                            (select min(t1.feauditoria)
                                                              from tmp t00, tzfw_audit_planilla t1
                                                              where t00.doc=t0.doc
                                                              and   t00.cdplaca = t1.cdplaca
                                                              and t00.cdcia_usuaria = t1.cdcia_usuaria
                                                              and t00.fingreso = t1.feingreso
                                                              and t00.nmtransito_documento = t1.nmtransito_documento
                                                              and t1.cdvalor_actual in(''N'',''E'',''T'')))),''ULTIMOCAMION'',
                     max(decode('''||CONTROLBASCULA||''',1,(select max(t00.febascula)
                                                              from tmp t00, tzfw_camiones t1
                                                              where t00.doc=t0.doc
                                                              and   t00.cdplaca = t1.cdplaca
                                                              and t00.fingreso = t1.feingreso),
                                                            (select max(t1.feauditoria)
                                                              from tmp t00, tzfw_audit_planilla t1
                                                              where t00.doc=t0.doc
                                                              and   t00.cdplaca = t1.cdplaca
                                                              and t00.cdcia_usuaria = t1.cdcia_usuaria
                                                              and t00.fingreso = t1.feingreso
                                                              and t00.nmtransito_documento = t1.nmtransito_documento
                                                              and t1.cdvalor_actual in(''N'',''E'',''T''))))) fecha
              from tmp t0
              group by t0.cdplaca, t0.feingreso, t0.nmtransito_documento,t0.cdcia_usuaria),
          documentos as(
              select t.cdplaca, t.feingreso, t.cdcia_usuaria, t.nmtransito_documento, count(1) total
              from tmp t, tzfw_documentos_x_cia j
              where j.cdplaca = t.cdplaca
              and j.feingreso = t.fingreso
              and j.cdcia_usuaria = t.cdcia_usuaria
              and j.nmtransito_documento = t.nmtransito_documento
              and j.snparcial=''S''
              group by t.cdplaca, t.feingreso, t.cdcia_usuaria, t.nmtransito_documento),
          estados as(
          select t.cdplaca, t.feingreso,t.cdcia_usuaria,t.nmtransito_documento,
                 case when trunc(febascula) <= to_date('''||FECHAPRODUCCION||''',''dd/mm/yyyy'') then ''X''
                      when SNPROPIOS_MEDIOS =''S'' and nvl(PLANILLA_RECEPCION,''N'')=''N'' then ''N''
                      when (select count(1) from tzfw_estados_planilla d where cdestado=''P'' and d.cdplaca = t.cdplaca and d.feingreso = t.fingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''P''
                      when (select count(1) from tzfw_estados_planilla d where cdestado=''T'' and d.cdplaca = t.cdplaca and d.feingreso = t.fingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''T''
                      when (select count(1) from tzfw_estados_planilla d where cdestado=''E'' and d.cdplaca = t.cdplaca and d.feingreso = t.fingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''E''
                      when (select count(1) from tzfw_estados_planilla d where cdestado=''R'' and d.cdplaca = t.cdplaca and d.feingreso = t.fingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''R''
                      when (select count(1) from tzfw_estados_planilla d where cdestado=''S'' and d.cdplaca = t.cdplaca and d.feingreso = t.fingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''S''
                      when (select count(1) from tzfw_estados_planilla d where cdestado=''C'' and d.cdplaca = t.cdplaca and d.feingreso = t.fingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''C''
                      when (select count(1) from tzfw_estados_planilla d where cdestado=''N'' and d.cdplaca = t.cdplaca and d.feingreso = t.fingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''N''
                      else ''P''
                  end estado
          from tmp t
          )
          select distinct t0.cdplaca, t0.feingreso fingreso, to_char(t0.febascula,''yyyy-mm-dd hh24:mi:ss'') FECHA_REGISTRO ,
                   t0.cdcia_usuaria, t0.dscia_usuaria, t0.nmtransito_documento, t0.cdtipo_documento,
                   t0.dstipo_documento, t0.nmtotal_doctransporte,
                   t0.nmdoctransporte, t0.nmtransito, t0.nmtotal_contenedor,
                   t0.nmtotal_cont_x_camion, t0.snrecibo,
                  t0.dsrecibo, t0.cdusuario_recibo,
                   nvl(ferecibo,'' '') ferecibo, t0.sncierre, t0.id, t0.febascula, t0.nhoras_planilla,t0.NMCONTROL_HORA,
                   t0.planilla_recepcion, t0.NDIAS_FMM_ING,t0.ndias_planilla,t0.sngranvolumen,t0.SNPROPIOS_MEDIOS,t0.tipo, t0.FEESTADO,t0.snparcial, to_char(t0.fingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso ,
                  case when (sngranvolumen =''S'' and planilla_recepcion =''S'' and nvl(ndias_planilla,0) !=0) then (fecha + ndias_planilla)
                       when (sngranvolumen =''N'' and planilla_recepcion =''S'') then fecha  + nhoras_planilla/24
                       when total> 0 then  fecha  + NDIAS_FMM_ING
                       when nvl(planilla_recepcion,''N'') =''N'' then fecha  + NMCONTROL_HORA/24
                       else fecha  + nhoras_planilla/24
                  end fechaReferencia ,
                  case
                        when (sngranvolumen =''S'' and planilla_recepcion =''S'' and nvl(ndias_planilla,0) !=0) then
                           ''DiasPlanilla (''||ndias_planilla||'')''
                       when (sngranvolumen =''N'' and planilla_recepcion =''S'') then
                           ''HorasPlanilla (''||nhoras_planilla||'')''
                       when (total> 0) then ''DiasFMM (''||NDIAS_FMM_ING||'')''
                       when nvl(planilla_recepcion,''N'') =''N'' then ''HorasFMM (''||NMCONTROL_HORA||'')''
                       else ''HorasPlanilla (''||nhoras_planilla||'')''
                   end  CONTROL_TIEMPO,
                   case when (sngranvolumen =''S'' and planilla_recepcion =''S'' and nvl(ndias_planilla,0) !=0) then ''DP''
                         when (sngranvolumen =''N'' and planilla_recepcion =''S'' ) then ''HP''
                        when (total > 0) then ''DF''
                        when planilla_recepcion =''N'' then ''HF''
                        else ''HP''
                   end  CONTROL,
                   decode(estado,''P'',''PENDIENTE'',''T'',''ENVIADO TRANSITO'',''E'',''ENVIADO'',''R'',''REVISION'',''S'',''SUSPENDIDO'',''C'',''RECEPCIONADO'',''N'',''NO APLICA'',''X'','' '') estado_planilla,
                   case when SNPROPIOS_MEDIOS =''S'' and nvl(PLANILLA_RECEPCION,''N'')=''N'' then ''N''
                   else estado end cdestado,FESALIDA
          from tmp t0, fecha t1, documentos t2, estados t3
          where t0.cdplaca = t1.cdplaca
          and t0.feingreso = t1.feingreso
          and t0.cdcia_usuaria = t1.cdcia_usuaria
          and t0.nmtransito_documento = t1.nmtransito_documento
          and t0.cdplaca = t2.cdplaca(+)
          and t0.feingreso = t2.feingreso(+)
          and t0.cdcia_usuaria = t2.cdcia_usuaria(+)
          and t0.nmtransito_documento = t2.nmtransito_documento(+)
          and t0.cdplaca = t3.cdplaca(+)
          and t0.feingreso = t3.feingreso(+)
          and t0.cdcia_usuaria = t3.cdcia_usuaria(+)
          and t0.nmtransito_documento = t3.nmtransito_documento(+)
          and t0.tipo=''P''
          union all
          select distinct t0.cdplaca, to_char(t0.feestado,''yyyy-mm-dd hh24:mi:ss'') fingreso, t0.FECHA_REGISTRO ,
                   t0.cdcia_usuaria, t0.dscia_usuaria, t0.nmtransito_documento, t0.cdtipo_documento,
                   t0.dstipo_documento, t0.nmtotal_doctransporte,
                   t0.nmdoctransporte, t0.nmtransito, t0.nmtotal_contenedor,
                   t0.nmtotal_cont_x_camion, t0.snrecibo,
                  t0.dsrecibo, t0.cdusuario_recibo,
                   nvl(t0.ferecibo,'' '') ferecibo, t0.sncierre, t0.id, t0.feestado, t0.nhoras_planilla,t0.NMCONTROL_HORA,
                   t0.planilla_recepcion, t0.NDIAS_FMM_ING,t0.ndias_planilla,t0.sngranvolumen,t0.SNPROPIOS_MEDIOS,t0.tipo, t0.FEESTADO,t0.snparcial, to_char(t0.feestado,''yyyy-mm-dd hh24:mi:ss'') feingreso ,
                  case when (nvl(PLANILLA_RECEPCION,''N'') =''S'') then FEESTADO + NMCONTROL_HORA/24
                       when (snparcial =''S'' and nvl(NDIAS_FMM_ING,0) != 0) then FEESTADO + NDIAS_FMM_ING
                       when (nvl(snparcial,''N'') =''N'' and nvl(NMCONTROL_HORA,0) !=0) then FEESTADO + NMCONTROL_HORA/24
                  end  fechaReferencia ,
                  case
                         when (nvl(PLANILLA_RECEPCION,''N'') =''S'') then ''HorasFMM (''||NMCONTROL_HORA||'')''
                         when (snparcial =''S'' and nvl(NDIAS_FMM_ING,0) != 0) then ''DiasFMM (''|| NDIAS_FMM_ING||'')''
                         when (nvl(snparcial,''N'') =''N'' and nvl(NMCONTROL_HORA,0) !=0) then ''HorasFMM (''||NMCONTROL_HORA||'')''
                      end  CONTROL_TIEMPO,
                   case when (snparcial =''S'' and nvl(NDIAS_FMM_ING,0) != 0) then ''DF''
                        when (nvl(snparcial,''N'') =''N'' and nvl(NMCONTROL_HORA,0) !=0) then ''HF''
                    end  CONTROL,
                   decode(estado,''N'',''NO APLICA'',''T'',''ENVIADO TRANSITO'',''P'',''PENDIENTE'',''E'',''ENVIADO'',''R'',''REVISION'',''S'',''SUSPENDIDO'',''C'',''RECEPCIONADO'',''N'','' '','' '') estado_planilla,
                   estado cdestado,'' '' FESALIDA
          from tmp t0, fecha t1, documentos t2, estados t3
          where t0.cdplaca = t1.cdplaca
          and t0.feingreso = t1.feingreso
          and t0.cdcia_usuaria = t1.cdcia_usuaria
          and t0.nmtransito_documento = t1.nmtransito_documento
          and t0.cdplaca = t2.cdplaca(+)
          and t0.feingreso = t2.feingreso(+)
          and t0.cdcia_usuaria = t2.cdcia_usuaria(+)
          and t0.nmtransito_documento = t2.nmtransito_documento(+)
          and t0.cdplaca = t3.cdplaca(+)
          and t0.feingreso = t3.feingreso(+)
          and t0.cdcia_usuaria = t3.cdcia_usuaria(+)
          and t0.nmtransito_documento = t3.nmtransito_documento(+)
          and t0.tipo=''F''
          )a) b
          where rownum >= ('||inmbRegistros||') and rownum < (300) '||replace(vchVencimiento,'CONTROL_TIEMPO','CONTROL');
-- where rownum >= ('||inmbRegistros||') and rownum < ('||nmbLimite||') '||replace(vchVencimiento,'CONTROL_TIEMPO','CONTROL');

        dbms_output.put_line(vchXQuery);
        oclbXML := dbms_xmlgen.getXML(vchXQuery);
return;
end XControlIngresos;
------------------------------------------------------XControlIngresos.prc-----------------------------------------------------------
procedure XControlIngresosOld(
    ivchFilter      in varchar2,
    IvchFilter2     in varchar2,
    ivchVencimiento in varchar2,
    inmbRegistros   in number,
    inmbLimite      in number,
    oclbXML         out clob)
is
    vchFilter       varchar2(1024);
    vchFilter2       varchar2(1024);
    vchFilter3       varchar2(1024);
    vchVencimiento   varchar2(1024);
    nmbLimite       number;
    vchXQuery       clob;
    vchControl      varchar2(2000);
    CONTROLBASCULA  tzfw_parametros.dsvalor%type;
    INICIOTIEMPO    tzfw_parametros.dsvalor%type;
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
function CondicionFiltro$
return varchar2
is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;

--------------------------------------------------CondicionFiltro2$-----------------------------------------------------
function CondicionFiltro3$
return varchar2
is
    begin
        vchFilter3 := replace(vchFilter3,'?','''');
        vchFilter3 := replace(vchFilter3,'[','<');
        vchXQuery := null;
        if (vchFilter3 is null) then return(vchXQuery); end if;
        return(vchFilter3);
    end CondicionFiltro3$;
--=====================================================================================================================
begin
        vchFilter := ivchFilter;
        vchFilter2 := ivchFilter;
        vchVencimiento := replace(ivchVencimiento,'?','''');
        vchVencimiento := replace(vchVencimiento,'[','<');
        vchFilter3 := SUBSTR(IvchFilter2, 4);
        nmbLimite := inmbRegistros + inmbLimite;

        begin
          select dsvalor into CONTROLBASCULA from tzfw_parametros where dsParametro='CONTROLBASCULA';
        exception
          when no_data_found then
          CONTROLBASCULA:='1';
        end;

         begin
          select dsvalor into INICIOTIEMPO from tzfw_parametros where dsParametro='INICIOTIEMPO';
        exception
          when no_data_found then
          INICIOTIEMPO:='PRIMERCAMION';
        end;

        vchControl := '(select decode('''||INICIOTIEMPO||''',''PRIMERCAMION'',min(decode('''||CONTROLBASCULA||''',1,t0.febascula,t12.fedescargue)),'
                    ||'''ULTIMOCAMION'',max(decode('''||CONTROLBASCULA||''',1,t0.febascula,t12.fedescargue))) fecha '
                    ||' from tzfw_camiones t0, tzfw_transitos_documentos t11, tzfw_documentos_x_cia t12 '
                    ||' where t0.cdplaca = t11.cdplaca and  t11.cdcia_usuaria =t.cdcia_usuaria '
                    ||' and t0.feingreso =t11.feingreso '
                    ||' and nvl(t11.nmtransito,t11.nmdoctransporte) =nvl(t.nmtransito,t.nmdoctransporte) '
                    ||' and t11.cdplaca = t12.cdplaca(+) '
                    ||' and t11.feingreso = t12.feingreso(+) '
                    ||' and t11.cdcia_usuaria = t12.cdcia_usuaria(+) '
                    ||' and t11.nmtransito_documento = t12.nmtransito_documento(+)) ';

        vchXQuery := 'select b.* '
        || 'from ( '
        || 'select to_char(fechaReferencia,''yyyy-mm-dd hh24:mi:ss'') fecha_vencimiento, rownum as nreg, a.* '
        || 'from ( '
        || 'select '
        || 't.cdplaca, '
        || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso , '
        || 'to_char(ca.febascula,''yyyy-mm-dd hh24:mi:ss'') FECHA_REGISTRO , '
        || 't.cdcia_usuaria, '
        || 'c.dscia_usuaria, '
        || 'to_char(t.nmtransito_documento) nmtransito_documento, '
        || 'nvl(t.cdtipo_documento,'' '') cdtipo_documento, '
        || 'nvl((select i.dstipo_ingreso from TZFW_TIPOS_INGRESO i where t.cdtipo_documento = i.cdtipo_ingreso ),'' '') dstipo_documento, '
        || 'nvl(to_char(t.nmtotal_doctransporte),''0'') nmtotal_doctransporte, '
        || 'nvl(t.nmdoctransporte, '' '') nmdoctransporte, '
        || 'nvl(t.nmtransito , '' '') nmtransito, '
        || 'nvl(to_char(t.nmtotal_contenedor),0) nmtotal_contenedor, '
        || 'nvl(to_char(t.nmtotal_cont_x_camion ),0) nmtotal_cont_x_camion, '
        || 'nvl(t.snrecibo,''N'') snrecibo, '
        || 'decode(t.snrecibo ,''N'',''NO'',''S'',''SI'',''NO'') dsrecibo, '
        || 'nvl(t.cdusuario_recibo, '' '') cdusuario_recibo, '
        || 'nvl(to_char(t.ferecibo,''yyyy-mm-dd hh24:mi:ss''),'' '') ferecibo, '
        || 't.sncierre, '
        || 't.id, case
              when (t.sngranvolumen =''S'' and j.planilla_recepcion =''S'' and nvl(c.ndias_planilla,0) !=0) then
                 '||vchControl||'+ c.ndias_planilla
             when (select count(1) from tzfw_documentos_x_cia j
                  where j.cdplaca = t.cdplaca and j.feingreso = t.feingreso
                 and j.cdcia_usuaria = t.cdcia_usuaria and j.nmtransito_documento = t.nmtransito_documento
                 and j.snparcial=''S'')> 0 then
                  '||vchControl||' + c.NDIAS_FMM_ING
            when j.planilla_recepcion =''N'' then
                  '||vchControl||' + c.NMCONTROL_HORA/24
              else
                '||vchControl||' + c.nhoras_planilla/24
            end fechaReferencia,
            case
              when (t.sngranvolumen =''S'' and j.planilla_recepcion =''S'' and nvl(c.ndias_planilla,0) !=0) then
                 ''DiasPlanilla (''||c.ndias_planilla||'')''
             when (select count(1) from tzfw_documentos_x_cia j
                  where j.cdplaca = t.cdplaca and j.feingreso = t.feingreso
                 and j.cdcia_usuaria = t.cdcia_usuaria and j.nmtransito_documento = t.nmtransito_documento
                 and j.snparcial=''S'')> 0 then
                  ''DiasFMM (''||c.NDIAS_FMM_ING||'')''
            when j.planilla_recepcion =''N'' then
                  ''HorasFMM (''||c.NMCONTROL_HORA||'')''
            else
                ''HorasPlanilla (''||c.nhoras_planilla||'')''
            end  CONTROL_TIEMPO,
            case
              when (t.sngranvolumen =''S'' and j.planilla_recepcion =''S'' and nvl(c.ndias_planilla,0) !=0) then
                 ''DP''
             when (select count(1) from tzfw_documentos_x_cia j
                  where j.cdplaca = t.cdplaca and j.feingreso = t.feingreso
                 and j.cdcia_usuaria = t.cdcia_usuaria and j.nmtransito_documento = t.nmtransito_documento
                 and j.snparcial=''S'')> 0 then
                  ''DF''
            when j.planilla_recepcion =''N'' then
                  ''HF''
            else
                ''HP''
            end  CONTROL,
            ''P'' tipo,
             (
            select case when ca.SNPROPIOS_MEDIOS =''S'' and nvl(j.PLANILLA_RECEPCION,''N'')=''N'' then ''NO APLICA''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''P'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''PENDIENTE''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''T'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''ENVIADO TRANSITO''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''E'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''ENVIADO''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''R'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''REVISION''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''S'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''SUSPENDIDO''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''C'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''RECEPCIONADO''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''N'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''NO APLICA''
                     else ''PENDIENTE''
                    end case
            from dual) estado_planilla, '
        ||'(
            select case when ca.SNPROPIOS_MEDIOS =''S'' and nvl(j.PLANILLA_RECEPCION,''N'')=''N'' then ''N''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''P'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''P''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''T'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''T''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''E'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''E''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''R'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''R''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''S'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''S''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''C'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''C''
                     when (select count(1) from tzfw_estados_planilla d where cdestado=''N'' and d.cdplaca = t.cdplaca and d.feingreso = t.feingreso and d.cdcia_usuaria = t.cdcia_usuaria and d.nmtransito_documento = t.nmtransito_documento) > 0 then ''N''
                     else ''P''
                    end case
            from dual) cdestado '
        || 'from TZFW_TRANSITOS_DOCUMENTOS t, '
        || ' TZFW_CIA_USUARIAS c, '
        || ' TZFW_CAMIONES ca, tzfw_tipos_ingreso j '
        || 'where t.cdcia_usuaria = c.cdcia_usuaria '
        || ' and t.cdtipo_documento is not null '
        ||' and t.cdtipo_documento = j.cdtipo_ingreso '
        || ' and t.cdplaca = ca.cdplaca '
        || ' and t.feingreso = ca.feingreso '
        || ' and ca.febascula is not null '
        || ' and ca.sningresa_carga = ''S'' '||CondicionFiltro$ --||' )a '||')b '
--        || 'where b.nreg >= ('||inmbRegistros||') and b.nreg < ('||nmbLimite||') '
        ||' union all
              select '' '' cdplaca, to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso ,
              to_char(ca.febascula,''yyyy-mm-dd hh24:mi:ss'') FECHA_REGISTRO ,
              t.cdcia_usuaria, c.dscia_usuaria,
            d.nmformulario_zf, '' '' cdtipo_documento,
            ''FORMULARIO'' dstipo_documento,
            '' '' , d.nmformulario_zf nmdoctransporte,
            '' '', '' '' nmtotal_contenedor,
            '' '' nmtotal_cont_x_camion, nvl(d.snrecibo,''N'') snrecibo,
            decode(d.snrecibo ,''N'',''NO'',''S'',''SI'',''NO'') dsrecibo, nvl(d.cdusuario_recibo, '' '') cdusuario_recibo,
            nvl(to_char(d.ferecibo,''yyyy-mm-dd hh24:mi:ss''),'' '') ferecibo, '' '' sncierre, d.id,
            case
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 p.FEESTADO + c.NDIAS_FMM_ING
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 p.FEESTADO + c.NDIAS_FMM_ING
               when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 p.FEESTADO + c.NMCONTROL_HORA/24
              when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 p.FEESTADO + c.NMCONTROL_HORA/24
            end fechaReferencia,
            case
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 ''DiasFMM (''|| c.NDIAS_FMM_ING||'')''
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 ''DiasFmm (''|| c.NDIAS_FMM_ING||'')''
               when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 ''HorasFMM (''||c.NMCONTROL_HORA||'')''
              when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 ''HorasFMM (''||c.NMCONTROL_HORA||'')''
            end CONTROL_HORAS,
            case
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 ''DF''
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 ''DF''
               when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 ''HF''
              when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 ''HF''
            end CONTROL,
            ''F'' tipo,
            decode(p.cdestado,''N'',''NO APLICA'',''T'',''ENVIADO TRANSITO'',''P'',''PENDIENTE'',''E'',''ENVIADO'',''R'',''REVISION'',''S'',''SUSPENDIDO'',''C'',''RECEPCIONADO'',''N'','' '','' '') estado_planilla,
            p.cdestado
            from TZFW_TRANSITOS_DOCUMENTOS t,  TZFW_CIA_USUARIAS c,  TZFW_CAMIONES ca , tzfw_documentos_x_cia d, tzfw_estados_planilla p
            where t.cdcia_usuaria = c.cdcia_usuaria  and t.cdtipo_documento is not null
            and t.cdplaca = ca.cdplaca  and t.feingreso = ca.feingreso
            and ca.febascula is not null
            and ca.sningresa_carga = ''S''
            and t.cdplaca =d.cdplaca
            and t.feingreso = d.feingreso
            and t.cdcia_usuaria = d.cdcia_usuaria
            and t.nmtransito_documento = d.nmtransito_documento
            and d.cdplaca = p.cdplaca
            and d.feingreso = p.feingreso
            and d.cdcia_usuaria = p.cdcia_usuaria
            and d.nmtransito_documento = p.nmtransito_documento
            and p.cdestado =''C''
            and d.nmconsecutivo_doc = p.nmconsecutivo_doc   '||replace(replace(CondicionFiltro$,'T.NMDOCTRANSPORTE','d.nmformulario_zf'),'T.SNRECIBO','d.SNRECIBO')||'
            )a '||')b '
         || 'where b.nreg >= ('||inmbRegistros||') and b.nreg < ('||nmbLimite||') '||replace(vchVencimiento,'CONTROL_TIEMPO','CONTROL');

        dbms_output.put_line(vchXQuery);
        oclbXML := dbms_xmlgen.getXML(vchXQuery);
return;
end XControlIngresosOld;
------------------------------------------------------XControlTiempoBloqueados.prc-----------------------------------------------------------
procedure XControlTiempoBloqueados(
ivchFilter in varchar2,
oclbXML out clob)
is
E VARCHAR2(1000);
vchFilter varchar2(1024);
vchXQuery2 clob;
vchConsulta clob;
vchFinal    clob;
vchControl      varchar2(2000);
CONTROLBASCULA  tzfw_parametros.dsvalor%type;
INICIOTIEMPO    tzfw_parametros.dsvalor%type;
FECHAPRODUCCION tzfw_parametros.dsvalor%type;

VENCIMIENTOS_TEMPORALES tzfw_parametros.dsvalor%type;
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
function CondicionFiltro$
return varchar2
is
begin
vchFilter := replace(vchFilter,'?','''');
vchFilter := replace(vchFilter,'[','<');
if (vchfilter is null) then return(vchFilter); end if;
return(vchfilter);
end CondicionFiltro$;
--=====================================================================================================================
begin
vchFilter := ivchFilter;
begin
  select dsvalor into FECHAPRODUCCION from tzfw_parametros where dsParametro='FECHA_PRODUCCION';
exception
  when no_data_found then
  FECHAPRODUCCION:=null;
end;

-- consulta antes de la salida a produccion
vchConsulta := 'with tmp1 as(select x.cdplaca,
                  to_char(x.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso,
                  x.cdcia_usuaria,
                  nvl(x.nmdoctransporte, x.nmtransito) nmdoctransporte,
                  x.febascula,
                  x.snbloqueado,
              --    x.id,
                  nvl(x.nmtransito, x.nmdoctransporte) nmtransito,
                  to_char(trunc(x.tiempo) || '':'' ||  trunc(round(mod(x.tiempo, trunc(x.tiempo))*60))) tiempo,''2'' tipo,
                  ''0'' tiempoFaltante,'' '' tipoDia '
              ||' from
              (select ch.*,
              abs(sysdate - ch.febascula - c.nmcontrol_hora/24)*24 tiempo
              from tzfw_transitos_documentos td,
                   tzfw_control_horas ch,
                   tzfw_cia_usuarias c,
                   tzfw_camiones ca
              where td.ferecibo is null
              and td.snrecibo is null
              and   ch.cdplaca = ca.cdplaca
              and   ch.feingreso = ca.feingreso
              and   ch.cdplaca = td.cdplaca
              and   ch.feingreso = td.feingreso
              and   (td.nmdoctransporte=ch.nmdoctransporte or td.nmtransito=ch.nmtransito)
             -- and   ch.snbloqueado = ''S''
              and   ca.sningresa_carga = ''S''
              and   ch.cdcia_usuaria = td.cdcia_usuaria
              and   trunc(ch.febascula) <= to_date('''||FECHAPRODUCCION||''',''dd/mm/yyyy'')
        and (ch.febascula + (c.nmcontrol_hora/24) - sysdate)<0
              and   c.cdcia_usuaria = td.cdcia_usuaria ' ||CondicionFiltro$ || '
              ) x),  ' ;

-- Control de tiempos estados planilla placas y formularios
      /*  begin
          select dsvalor into CONTROLBASCULA from tzfw_parametros where dsParametro='CONTROLBASCULA';
        exception
          when no_data_found then
          CONTROLBASCULA:='1';
        end;

         begin
          select dsvalor into INICIOTIEMPO from tzfw_parametros where dsParametro='INICIOTIEMPO';
        exception
          when no_data_found then
          INICIOTIEMPO:='PRIMERCAMION';
        end;

    vchControl := '(select decode('''||INICIOTIEMPO||''',''PRIMERCAMION'',min(decode('''||CONTROLBASCULA||''',1,t0.febascula,t12.fedescargue)),'
                    ||'''ULTIMOCAMION'',max(decode('''||CONTROLBASCULA||''',1,t0.febascula,t12.fedescargue))) fecha '
                    ||' from tzfw_camiones t0, tzfw_transitos_documentos t11, tzfw_documentos_x_cia t12 '
                    ||' where t0.cdplaca = t11.cdplaca and  t11.cdcia_usuaria =t.cdcia_usuaria '
                    ||' and t0.feingreso =t11.feingreso '
                    ||' and nvl(t11.nmtransito,t11.nmdoctransporte) =nvl(t.nmtransito,t.nmdoctransporte) '
                    ||' and t11.cdplaca = t12.cdplaca(+) '
                    ||' and t11.feingreso = t12.feingreso(+) '
                    ||' and t11.cdcia_usuaria = t12.cdcia_usuaria(+) '
                    ||' and t11.nmtransito_documento = t12.nmtransito_documento(+)) ';

        vchConsulta := vchConsulta||
       -- ' select dsvalor,round((sysdate-fechaReferencia)*24,2) tiempoTranscurrido,
      --  round((fecha_vencimiento-sysdate)*24,2) tiempoFaltante,
      ' union all select a.cdplaca,'' '' fecha,'' '' cia,doc nmdoc_transporte, fecha_vencimiento, ''N'',a.id, doc, '||
      ' case when abs(sysdate-fechaReferencia) <= 1then
             to_char(round((sysdate-fechaReferencia)*24,2))||'' HORAS ''
             else
               to_char(round(sysdate-fechaReferencia,2))||'' DIAS''
        end tiempo,
         case
           when fecha_vencimiento< sysdate then ''-1''
           when (sysdate between fecha_vencimiento-valor/2 and fecha_vencimiento) then ''0''
           else ''1''
        end tipo,
        case when round((fecha_vencimiento-sysdate)*24,2) between 0 and -24 then
             to_char(round((fecha_vencimiento-sysdate)*24,2))||'' HORAS''
            when round((fecha_vencimiento-sysdate)*24,2) <-24 then
             to_char(round((fecha_vencimiento-sysdate),2))||'' DIAS''
             when abs(fecha_vencimiento -sysdate) <=1 then
                to_char(round((fecha_vencimiento -sysdate)*24,2))||'' HORAS''
             else
                to_char(round((fecha_vencimiento -sysdate),2))||'' DIAS''
             end tiempo_faltante, control_tiempo '
        || 'from ( '
        || 'select '
        || 't.cdplaca, '
        || 'to_char(t.nmtransito_documento) nmtransito_documento, '
        || 't.id, nvl(t.nmdoctransporte,t.nmtransito) doc,case
              when (t.sngranvolumen =''S'' and j.planilla_recepcion =''S'' and nvl(c.ndias_planilla,0) !=0)  then
                 ('||vchControl||'+ c.ndias_planilla)
             when (select count(1) from tzfw_documentos_x_cia j
                  where j.cdplaca = t.cdplaca and j.feingreso = t.feingreso
                 and j.cdcia_usuaria = t.cdcia_usuaria and j.nmtransito_documento = t.nmtransito_documento
                 and j.snparcial=''S'')> 0 then
                  ('||vchControl||' + c.NDIAS_FMM_ING)
            when j.planilla_recepcion =''N'' then
                  ('||vchControl||' + c.NMCONTROL_HORA/24)
              else
                ('||vchControl||' + c.nhoras_planilla/24)
            end fecha_Vencimiento,
            ('||vchControl||') fechaReferencia,
            case
              when (t.sngranvolumen =''S'' and j.planilla_recepcion =''S'' and nvl(c.ndias_planilla,0) !=0) then
                 ''DIAS''
             when (select count(1) from tzfw_documentos_x_cia j
                  where j.cdplaca = t.cdplaca and j.feingreso = t.feingreso
                 and j.cdcia_usuaria = t.cdcia_usuaria and j.nmtransito_documento = t.nmtransito_documento
                 and j.snparcial=''S'')> 0 then
                  ''DIAS''
            when j.planilla_recepcion =''N'' then
                  ''HORAS''
            else
                ''HORAS''
            end  CONTROL_TIEMPO,''P'' tipo,
            case
              when (t.sngranvolumen =''S'' and j.planilla_recepcion =''S'' and nvl(c.ndias_planilla,0) !=0)  then
                 c.ndias_planilla
             when (select count(1) from tzfw_documentos_x_cia j
                  where j.cdplaca = t.cdplaca and j.feingreso = t.feingreso
                 and j.cdcia_usuaria = t.cdcia_usuaria and j.nmtransito_documento = t.nmtransito_documento
                 and j.snparcial=''S'')> 0 then
               c.NDIAS_FMM_ING
            when j.planilla_recepcion =''N'' then
                  c.NMCONTROL_HORA/24
              else
                c.nhoras_planilla/24
            end valor '
        || 'from TZFW_TRANSITOS_DOCUMENTOS t, '
        || ' TZFW_CIA_USUARIAS c, '
        || ' TZFW_CAMIONES ca, tzfw_tipos_ingreso j '
        || 'where t.cdcia_usuaria = c.cdcia_usuaria '
        || ' and t.cdtipo_documento is not null '
        || ' and t.cdplaca = ca.cdplaca '
        ||' and t.cdtipo_documento = j.cdtipo_ingreso '
        ||' and trunc(ca.febascula) > to_date('''||FECHAPRODUCCION||''',''dd/mm/yyyy'') '
        || ' and t.feingreso = ca.feingreso '
        || ' and nvl(t.snrecibo,''N'') =''N'' '
        || ' and ca.febascula is not null '
        || ' and ca.sningresa_carga = ''S'' '||replace(CondicionFiltro$ ,'CH.CDCIA_USUARIA','c.cdcia_usuaria')
        ||' union all
              select '' '' cdplaca,
            d.nmformulario_zf,
            d.id,nvl(t.nmdoctransporte,t.nmtransito) doc,
            case
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 p.FEESTADO + c.NDIAS_FMM_ING
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 p.FEESTADO + c.NDIAS_FMM_ING
               when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 p.FEESTADO + c.NMCONTROL_HORA/24
              when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 p.FEESTADO + c.NMCONTROL_HORA/24
            end fechaVencimiento,
            ('||vchControl||') fechaReferencia,
            case
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 ''DIAS''
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 ''DIAS''
               when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 ''HORAS''
              when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 ''HORAS''
            end CONTROL_HORAS ,
            ''F'' tipo,
            case
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 c.NDIAS_FMM_ING
              when (d.snparcial =''S'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NDIAS_FMM_ING,0) != 0) then
                 c.NDIAS_FMM_ING
               when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''1'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 c.NMCONTROL_HORA/24
              when (nvl(d.snparcial,''N'') =''N'' and '||CONTROLBASCULA||'=''0'' and nvl(c.NMCONTROL_HORA,0) !=0) then
                 c.NMCONTROL_HORA/24
            end valor
            from TZFW_TRANSITOS_DOCUMENTOS t,  TZFW_CIA_USUARIAS c,  TZFW_CAMIONES ca , tzfw_documentos_x_cia d, tzfw_estados_planilla p
            where t.cdcia_usuaria = c.cdcia_usuaria  and t.cdtipo_documento is not null
            and t.cdplaca = ca.cdplaca  and t.feingreso = ca.feingreso
            and ca.febascula is not null
            and ca.sningresa_carga = ''S''
            and t.cdplaca =d.cdplaca
            and t.feingreso = d.feingreso
            and t.cdcia_usuaria = d.cdcia_usuaria
            and t.nmtransito_documento = d.nmtransito_documento
            and d.cdplaca = p.cdplaca
            and d.feingreso = p.feingreso
            and d.cdcia_usuaria = p.cdcia_usuaria
            and d.nmtransito_documento = p.nmtransito_documento
            and trunc(ca.febascula) > to_date('''||FECHAPRODUCCION||''',''dd/mm/yyyy'')
            and p.cdestado =''C''
            and nvl(d.snrecibo,''N'') =''N''
            and d.nmconsecutivo_doc = p.nmconsecutivo_doc   '||replace(CondicionFiltro$,'CH.CDCIA_USUARIA','c.cdcia_usuaria')
            ||' )a, tzfw_parametros b
            where b.dsparametro =''VENCIMIENTO_TEMPORALES'''
            ||' and fecha_vencimiento-dsvalor<=sysdate ';*/


 --  vchFinal := vchConsulta||vchXQuery2;
    vchXQuery2 := fvchBloqueados(CondicionFiltro$);

    dbms_output.put_line(vchConsulta||vchXQuery2);

    oclbXML := dbms_xmlgen.getXML(vchConsulta||vchXQuery2);


return;
end XControlTiempoBloqueados;
------------------------------------------------------XControlTiempoBloqueados.prc-----------------------------------------------------------
procedure XControlTiempoBloqueadosP(
ivchCia in varchar2,
inmbCantidad out number)
is
begin

          select nvl(count(*),0)
          into inmbCantidad
          from
              (select ch.*,
              abs(sysdate - ch.febascula - c.nmcontrol_hora/24)*24 tiempo
              from tzfw_transitos_documentos td,
                   tzfw_control_horas ch,
                   tzfw_cia_usuarias c,
                   tzfw_camiones ca
              where td.ferecibo is null
        and td.snrecibo is null
              and   ch.cdplaca = ca.cdplaca
              and   ch.feingreso = ca.feingreso
              and   ch.cdplaca = td.cdplaca
              and   ch.feingreso = td.feingreso
        and   (td.nmdoctransporte=ch.nmdoctransporte or td.nmtransito=ch.nmtransito)
              and   ca.sningresa_carga = 'S'
              and   ch.cdcia_usuaria = td.cdcia_usuaria
        and (ch.febascula + (c.nmcontrol_hora/24) - sysdate)<0
              and   c.cdcia_usuaria = td.cdcia_usuaria
              and ch.cdcia_usuaria = ivchCia) x;

return;
end XControlTiempoBloqueadosP;
------------------------------------------------------XControlTiempo.prc-----------------------------------------------------------
procedure XControlTiempo(
                      ivchFilter in varchar2,
                      ivchCia    in varchar2,
                      inmbRegistros in number,
                      inmbLimite in number,
                      oclbXML out clob)
is
Cursor cuBloqueo Is
   /* CONSULTA ZONA FRANCA */
--   select ch.*,abs((ch.febascula + (c.nmcontrol_hora/24))-sysdate)*24  tiempo
     select distinct ch.cdcia_usuaria, ch.cdplaca, ch.feingreso, ch.id, '1' tipo
    from tzfw_control_horas ch,
         tzfw_cia_usuarias c,
         tzfw_camiones ca,
         tzfw_transitos_documentos td
    where ch.cdcia_usuaria = c.cdcia_usuaria
    and   ca.cdplaca = ch.cdplaca
    and   ca.feingreso = ch.feingreso
    and   td.cdplaca = ch.cdplaca
    and   td.feingreso = ch.feingreso
    and   td.cdcia_usuaria = ch.cdcia_usuaria
    and   td.snrecibo is null
    and   td.ferecibo is null
    and   ch.snbloqueado = 'N'
    and   ca.sningresa_carga = 'S'
   -- and   p.dsparametro ='FECHA_PRODUCCION'
   -- and   trunc(ch.febascula) <= to_date(p.dsvalor,'dd/mm/yyyy')
    and (ch.febascula + (c.nmcontrol_hora/24) - sysdate)<0  ;


    regBloqueo cuBloqueo%rowtype;

    vchFilter varchar2(1024);
    FECHAPRODUCCION  tzfw_parametros.dsvalor%type;
    vparametro_motivo    VARCHAR2(20);
    existe_motivo       number;
    nmbLimite number;
    vchXQuery clob;
    vchXQuery2 clob;
    vchControl varchar2(2000);
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
function CondicionFiltro$
return varchar2
is
begin
vchFilter := replace(vchFilter,'?','''');
vchFilter := replace(vchFilter,'[','<');
if (vchfilter is null) then return(vchFilter); end if;
return(vchfilter);
end CondicionFiltro$;
--=====================================================================================================================
begin
vchFilter := ivchFilter;
nmbLimite := inmbRegistros + inmbLimite;

begin
  select dsvalor into FECHAPRODUCCION from tzfw_parametros where dsParametro='FECHA_PRODUCCION';
exception
  when no_data_found then
  FECHAPRODUCCION:=null;
end;

vchXQuery := ' with tmp1 as(select ch.cdplaca,
             to_char(ch.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso,
             ch.cdcia_usuaria,
             nvl(ch.nmdoctransporte,ch.nmtransito) nmdoctransporte,
             ch.febascula,
             ch.snbloqueado,
             nvl(ch.nmtransito,ch.nmdoctransporte) nmtransito,
             trunc(abs((ch.febascula + (c.nmcontrol_hora/24))-sysdate)*24)
            || '':'' || trunc(round(mod(abs((ch.febascula + (c.nmcontrol_hora/24))-sysdate)*24
                   , trunc(abs((ch.febascula + (c.nmcontrol_hora/24))-sysdate)*24
            ))*60))  tiempo,''2'' tipo,''0'' tiempoFaltante,'' ''tipoDia
              from tzfw_control_horas ch,
                   tzfw_cia_usuarias c,
                   tzfw_camiones ca,
                   tzfw_transitos_documentos td
              where ch.cdcia_usuaria = c.cdcia_usuaria
              and   ca.cdplaca = ch.cdplaca
              and   ca.feingreso = ch.feingreso
              and   td.cdplaca = ch.cdplaca
              and   td.feingreso = ch.feingreso
              and   td.cdcia_usuaria = ch.cdcia_usuaria
        and   (td.nmdoctransporte=ch.nmdoctransporte or td.nmtransito=ch.nmtransito)
              and   td.snrecibo is null
              and   td.ferecibo is null
              and   ch.snbloqueado = ''N''
              and   ca.sningresa_carga = ''S''
              and   trunc(ch.febascula) <= to_date('''||FECHAPRODUCCION||''',''dd/mm/yyyy'')
              and (ch.febascula + (c.nmcontrol_hora/24) - to_number((select p.dsvalor from tzfw_parametros p where p.dsparametro = ''CONTROL_INGRESO''))/24) <= sysdate '||CondicionFiltro$||'
        UNION
        select x.cdplaca,
                  to_char(x.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso,
                  x.cdcia_usuaria,
                  nvl(x.nmdoctransporte, x.nmtransito) nmdoctransporte,
                  x.febascula,
                  x.snbloqueado,
                  nvl(x.nmtransito, x.nmdoctransporte) nmtransito,
                  trunc(x.tiempo) || '':'' ||  trunc(round(mod(x.tiempo, trunc(x.tiempo))*60)) tiempo,''2'' tipo,
                  ''0'' tiempoFaltante,'' ''tipoDia
          from
              (select ch.*,
              abs(sysdate - ch.febascula - c.nmcontrol_hora/24)*24 tiempo
              from tzfw_transitos_documentos td,
                   tzfw_control_horas ch,
                   tzfw_cia_usuarias c,
                   tzfw_camiones ca
              where td.ferecibo is null
               and   td.snrecibo is null
              and   ch.cdplaca = ca.cdplaca
              and   ch.feingreso = ca.feingreso
              and   ch.cdplaca = td.cdplaca
              and   ch.feingreso = td.feingreso
              and   (td.nmdoctransporte=ch.nmdoctransporte or td.nmtransito=ch.nmtransito)
             -- and   ch.snbloqueado = ''S''
              and   ca.sningresa_carga = ''S''
              and   ch.cdcia_usuaria = td.cdcia_usuaria
              and (ch.febascula + (c.nmcontrol_hora/24) - sysdate)<0
              and   trunc(ch.febascula) <= to_date('''||FECHAPRODUCCION||''',''dd/mm/yyyy'')
              and   c.cdcia_usuaria = td.cdcia_usuaria' ||CondicionFiltro$ || ') x), ';

    vchXQuery2 := fvchBloqueados(CondicionFiltro$);

    dbms_output.put_line(vchXQuery||vchXQuery2);

    oclbXML := dbms_xmlgen.getXML(vchXQuery||vchXQuery2);

/*
For regBloqueo In cuBloqueo Loop
    Update tzfw_cia_usuarias
    Set    snbloqueo = 'S'
    Where  cdcia_usuaria    = regBloqueo.Cdcia_Usuaria;

    if regBloqueo.tipo ='1' then
        Update tzfw_control_horas
        set    snbloqueado = 'S'
        where  cdplaca = regBloqueo.Cdplaca
        and    feingreso = regBloqueo.Feingreso
        and    cdcia_usuaria = regBloqueo.Cdcia_Usuaria
        and    id            = regBloqueo.Id;
    end if;
    commit;
end loop;
*/
fvchBloqueoCompania(ivchCia);

return;
end XControlTiempo;
------------------------------------------------------XControlTiempo.prc-----------------------------------------------------------
/*procedure XControlTiempoProvisional
is
Cursor cuBloqueo Is
   -- bloqueo de comap??ias que no han legalizado los formularios en el tiempo limite estipulado
     select t.cdcia_usuaria  , t.id
      from tzfw_control_provisional t, tzfw_parametros t1, tzfw_formularios t3
      where t1.dsparametro ='TIEMPOPROVISIONAL'
      and t.snbloqueado='N'
      and round(24 * (sysdate - t.feaprobacion),2) > to_number(t1.dsvalor)
      and t.cdcia_usuaria = t3.cdcia_usuaria
      and t.nmformulario_zf = t3.nmformulario_zf
      and t3.cdestado != '4';

    regBloqueo cuBloqueo%rowtype;

--=====================================================================================================================
begin
For regBloqueo In cuBloqueo Loop
    Update tzfw_cia_usuarias
    Set    snbloqueo = 'S'
    Where  cdcia_usuaria    = regBloqueo.Cdcia_Usuaria;

    Update tzfw_control_provisional
    set    snbloqueado = 'S'
    where  id = regBloqueo.id;
    commit;

end loop;

return;
end XControlTiempoProvisional;*/
---------------------------------------------------------------------------------------------------------------
procedure fvchBloqueoCompania(ivchCia in varchar2 default null)
is
    Cursor cuBloqueo(
        inmbValor$           IN number
        ) Is
   -- bloqueo de comap?? que no han legalizado los formularios en el tiempo limite estipulado
      select t.cdcia_usuaria  , t.id
      from tzfw_control_provisional t,  tzfw_formularios t3 , tzfw_cia_usuarias t2
      where round(24 * (sysdate - t.feaprobacion),2) > inmbValor$
      and t.cdcia_usuaria = t3.cdcia_usuaria
      and t.cdcia_usuaria = t2.cdcia_usuaria
      and t2.snbloqueo ='N'
      and t.nmformulario_zf = t3.nmformulario_zf
      and t.cdcia_usuaria = nvl(ivchCia, t.cdcia_usuaria)
      and t3.cdestado not in('4','A');

   CONTROLBASCULA     tzfw_parametros.dsvalor%type;
   INICIOTIEMPO       tzfw_parametros.dsvalor%type;
   FECHAPRODUCCION    tzfw_parametros.dsvalor%type;
   TIEMPOPROVISIONAL  number;
   i                  number := 0;

   cursor cuBloqueoNew is
   with cias as(
   select * 
   from tzfw_cia_usuarias t
   where t.cdcia_usuaria = nvl(ivchCia,t.cdcia_usuaria)
   and t.snbloqueo ='N'
   and (nhoras_planilla != 0 or NMCONTROL_HORA !=0 or NDIAS_FMM_ING !=0 or ndias_planilla !=0)),
   planillas as(
   select /*MATERIALIZE*/ t.cdplaca, t.nmtransito_documento, t.id, nvl(t.nmdoctransporte,t.nmtransito) doc, 'P' tipo ,
            sngranvolumen  ,planilla_recepcion,c.ndias_planilla, t.cdcia_usuaria , t.feingreso, ca.febascula,
            c.nhoras_planilla, c.NMCONTROL_HORA , c.NDIAS_FMM_ING ,t.nmdoctransporte, snbloqueo, t.nmtransito,
            sysdate feestado, ' ' snparcial,' ' nmformulario_zf
     from TZFW_TRANSITOS_DOCUMENTOS t,  cias c,  TZFW_CAMIONES ca, tzfw_tipos_ingreso j
     where t.cdcia_usuaria = c.cdcia_usuaria
     and   t.cdplaca = ca.cdplaca
     and   t.feingreso = ca.feingreso
     and   t.cdtipo_documento = j.cdtipo_ingreso
     and   nvl(t.snrecibo,'N') ='N'
     and   ca.febascula > to_date(FECHAPRODUCCION,'dd/mm/yyyy')
     and   ca.sningresa_carga = 'S')    
     ,
formularios as(
    select /*MATERIALIZE*/ t.cdplaca, t.nmtransito_documento, d.id, nvl(t.nmdoctransporte,t.nmtransito) doc, 'F' tipo ,
         sngranvolumen  ,f0.planilla_recepcion,c.ndias_planilla, t.cdcia_usuaria , t.feingreso, ca.febascula,
         c.nhoras_planilla, c.NMCONTROL_HORA , c.NDIAS_FMM_ING ,t.nmdoctransporte, snbloqueo, t.nmtransito,FEESTADO,
         d.snparcial, nmformulario_zf
    from TZFW_TRANSITOS_DOCUMENTOS t,  cias c,  TZFW_CAMIONES ca , tzfw_documentos_x_cia d, tzfw_estados_planilla p, tzfw_tipos_ingreso f0
    where t.cdcia_usuaria = c.cdcia_usuaria
    and t.cdplaca = ca.cdplaca
    and t.feingreso = ca.feingreso
    and ca.febascula > to_date(FECHAPRODUCCION,'dd/mm/yyyy')
    and ca.sningresa_carga = 'S'
    and t.cdplaca =d.cdplaca
    and t.CDTIPO_DOCUMENTO = f0.cdtipo_ingreso
    and t.feingreso = d.feingreso
    and t.cdcia_usuaria = d.cdcia_usuaria
    and t.nmtransito_documento = d.nmtransito_documento
    and d.cdplaca = p.cdplaca
    and d.feingreso = p.feingreso
    and d.cdcia_usuaria = p.cdcia_usuaria
    and d.nmtransito_documento = p.nmtransito_documento
    and p.cdestado ='C'
    and nvl(d.snrecibo,'N') ='N'
    and d.nmconsecutivo_doc = p.nmconsecutivo_doc    
    ),
tmp as(
select * from planillas union all select * from formularios )
,    
fecha as(
    select  t0.cdplaca,doc,t00.febascula, t0.feingreso,t0.nmtransito_documento,t0.cdcia_usuaria, 
    decode (INICIOTIEMPO,'PRIMERCAMION',
             decode(CONTROLBASCULA,'1',min(t0.febascula) over (partition by t0.doc),
                            min(t1.feauditoria) over (partition by t0.doc)),
            decode(CONTROLBASCULA,'1', max(t0.febascula) over (partition by t0.doc),
                            max(t1.feauditoria) over (partition by t0.doc))) fechaReferencia 
    from tmp t0 inner join tzfw_camiones t00 on (t0.cdplaca = t00.cdplaca and t0.feingreso = t00.feingreso)
    left outer join tzfw_audit_planilla t1 on(t0.cdplaca = t1.cdplaca
                                                          and t0.cdcia_usuaria = t1.cdcia_usuaria
                                                          and t0.feingreso = t1.feingreso
                                                          and t0.nmtransito_documento = t1.nmtransito_documento
                                                          and t1.cdvalor_actual in('N','E','T'))),
documentos as(
    select t.cdplaca, t.feingreso, t.cdcia_usuaria, t.nmtransito_documento, count(1) total
    from tmp t, tzfw_documentos_x_cia j
    where j.cdplaca = t.cdplaca
    and j.feingreso = t.feingreso
    and j.cdcia_usuaria = t.cdcia_usuaria
    and j.nmtransito_documento = t.nmtransito_documento
    and j.snparcial='S'
    group by t.cdplaca, t.feingreso, t.cdcia_usuaria, t.nmtransito_documento)   
    ,
tmpfinal as(
    select a.cdplaca, a.id,tipo, a.cdcia_usuaria, nvl(a.nmdoctransporte,nmtransito) doc,
           case when (sngranvolumen ='S' and planilla_recepcion ='S' and nvl(ndias_planilla,0) !=0)  then
                (fechaReferencia + ndias_planilla)
                when (sngranvolumen ='N' and planilla_recepcion ='S') then fechaReferencia  + nhoras_planilla/24
                when total > 0 then (fechaReferencia  + NDIAS_FMM_ING)
                when planilla_recepcion ='N' then  (fechaReferencia  + NMCONTROL_HORA/24)
                else (fechaReferencia  + nhoras_planilla/24) end fecha_Vencimiento,
            case when (sngranvolumen ='S' and planilla_recepcion ='S' and nvl(ndias_planilla,0) !=0)  then
                'Excedio el tiempo para enviar los datos de la planilla de recepcion '
                when (sngranvolumen ='N' and planilla_recepcion ='S') then 'Excedio el tiempo para enviar los datos de la planilla de recepcion '
                when total > 0 then 'Excedio el tiempo para autorizar el formulario '
                when planilla_recepcion ='N' then  'Excedio el tiempo para autorizar el formulario '
                else 'Excedio el tiempo para enviar los datos de la planilla de recepcion ' end
            dsmotivo
    from tmp a, fecha b , documentos c
    where a.cdplaca = b.cdplaca
    and a.feingreso = b.feingreso
    and a.nmtransito_documento = b.nmtransito_documento
    and a.cdcia_usuaria = b.cdcia_usuaria
    and tipo='P'
    and a.cdplaca = c.cdplaca(+)
    and a.feingreso = c.feingreso(+)
    and a.nmtransito_documento = c.nmtransito_documento(+)
    and a.cdcia_usuaria = c.cdcia_usuaria(+)
    union all
    select a.cdplaca,a.id,tipo, a.cdcia_usuaria, nmformulario_zf doc,
           case when (nvl(PLANILLA_RECEPCION,'N') ='S')  then  FEESTADO + NMCONTROL_HORA/24
                when (snparcial ='S' and CONTROLBASCULA='1' and nvl(NDIAS_FMM_ING,0) != 0) then FEESTADO + NDIAS_FMM_ING
                when (snparcial ='S' and CONTROLBASCULA='0' and nvl(NDIAS_FMM_ING,0) != 0) then FEESTADO + NDIAS_FMM_ING
                when (nvl(snparcial,'N') ='N' and CONTROLBASCULA='1' and nvl(NMCONTROL_HORA,0) !=0) then  FEESTADO + NMCONTROL_HORA/24
                when (nvl(snparcial,'N') ='N' and CONTROLBASCULA='0' and nvl(NMCONTROL_HORA,0) !=0) then  FEESTADO + NMCONTROL_HORA/24
           end fecha_Vencimiento,
           case when (nvl(PLANILLA_RECEPCION,'N') ='S')  then  'Excedio el tiempo para autorizar el formulario '
                when (snparcial ='S' and CONTROLBASCULA='1' and nvl(NDIAS_FMM_ING,0) != 0) then 'Excedio el tiempo para autorizar el formulario '
                when (snparcial ='S' and CONTROLBASCULA='0' and nvl(NDIAS_FMM_ING,0) != 0) then 'Excedio el tiempo para autorizar el formulario '
                when (nvl(snparcial,'N') ='N' and CONTROLBASCULA='1' and nvl(NMCONTROL_HORA,0) !=0) then  'Excedio el tiempo para autorizar el formulario '
                when (nvl(snparcial,'N') ='N' and CONTROLBASCULA='0' and nvl(NMCONTROL_HORA,0) !=0) then  'Excedio el tiempo para autorizar el formulario '
           end
    from tmp a, fecha b , documentos c
    where a.cdplaca = b.cdplaca
    and a.feingreso = b.feingreso
    and a.nmtransito_documento = b.nmtransito_documento
    and a.cdcia_usuaria = b.cdcia_usuaria
    and tipo='F'
    and a.cdplaca = c.cdplaca(+)
    and a.feingreso = c.feingreso(+)
    and a.nmtransito_documento = c.nmtransito_documento(+)
    and a.cdcia_usuaria = c.cdcia_usuaria(+)
    )
    select distinct * from tmpFinal t
    where fecha_vencimiento-sysdate <0
    -- poner la compa?ia
    and id not in (select id_doc from tzfw_motivo_bloqueo m where m.cdcia_usuaria =t.cdcia_usuaria and m.cdtipo=tipo and m.cdestado = nvl2(ivchCia,m.cdestado,'A') and t.fecha_vencimiento = m.fevencimiento);

    regBloqueo          cuBloqueo%rowtype;
    regBloqueoNew       cuBloqueoNew%rowtype;

begin

   begin
      select to_number(dsvalor) into TIEMPOPROVISIONAL from tzfw_parametros where dsParametro='TIEMPOPROVISIONAL';
    exception
      when no_data_found then
      TIEMPOPROVISIONAL:=null;
    end;

   For regBloqueo In cuBloqueo(TIEMPOPROVISIONAL) Loop
      if (i = 0 and ivchCia is not null) then
          Update tzfw_cia_usuarias
          Set    snbloqueo = 'S'
          Where  cdcia_usuaria    = regBloqueo.Cdcia_Usuaria;
          i := 1;
      else
         if (ivchCia is null) then
           Update tzfw_cia_usuarias
           Set    snbloqueo = 'S'
           Where  cdcia_usuaria    = regBloqueo.Cdcia_Usuaria;
         end if;  
      end if;
      Update tzfw_control_provisional
      set    snbloqueado = 'S'
      where  id = regBloqueo.id;
      commit;
   end loop;

    begin
      select dsvalor into FECHAPRODUCCION from tzfw_parametros where dsParametro='FECHA_PRODUCCION';
    exception
      when no_data_found then
      FECHAPRODUCCION:=null;
    end;

    begin
      select dsvalor into CONTROLBASCULA from tzfw_parametros where dsParametro='CONTROLBASCULA';
    exception
      when no_data_found then
       CONTROLBASCULA:='1';
    end;

    begin
       select dsvalor into INICIOTIEMPO from tzfw_parametros where dsParametro='INICIOTIEMPO';
    exception
      when no_data_found then
       INICIOTIEMPO:='PRIMERCAMION';
    end;

    For regBloqueoNew In cuBloqueoNew Loop
        insert into tzfw_motivo_bloqueo (id,
              cdcia_usuaria,
              nmformulario_zf,
              fevencimiento,
              cdestado,
              feestado,
              dsmotivo,
              snbloqueo,
              cdtipo,
              id_doc)
              values(
              SEQ_TZFW_TZFW_MOTIVO_BLOQUEO.Nextval,
               regBloqueoNew.cdcia_usuaria  ,
--               nvl(regBloqueoNew.doc,'SIN FMM '||regBloqueoNew.cdplaca),
               regBloqueoNew.doc,
               regBloqueoNew.fecha_vencimiento,'A',sysdate,
               regBloqueoNew.dsmotivo,
               'S',
               regBloqueoNew.tipo,
               regBloqueoNew.id);
    end loop;

    update tzfw_cia_usuarias set snbloqueo='S' where cdcia_usuaria in(
    select cdcia_usuaria
        from tzfw_motivo_bloqueo where cdestado='A')
        and snbloqueo='N';
    commit;

end fvchBloqueoCompania;
---------------------------------------------------------------------------------------------------------------
procedure XControlTiempoProvisional(
        ivchFilter in varchar2,
        ivchCia    in tzfw_transitos_documentos.cdcia_usuaria%type,                      
        oclbXML out clob)
is

    vchFilter varchar2(1024);
    nmbLimite number;
    vchXQuery varchar2(5048);

--------------------------------------------------CondicionFiltro$-----------------------------------------------------
    function CondicionFiltro$
    return varchar2
    is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;
--=====================================================================================================================
begin
vchFilter := ivchFilter;

vchXQuery := 'select t.NMFORMULARIO_ZF, t.feaprobacion,
                     case
                      when round(24 * (sysdate - t.feaprobacion),2) between to_number(t2.dsvalor) and to_number(t1.dsvalor) then ''Alerta''
                      when round(24 * (sysdate - t.feaprobacion),2) > to_number(t1.dsvalor) then ''Bloquea''
                     -- when round(24 * (sysdate - t.feaprobacion),2) < to_number(t2.dsvalor) then ''Nada''
                     end accion,
                     to_number(t1.dsvalor)-round(24 * (sysdate - t.feaprobacion),2) tiempoFaltante,
                     to_number(t2.dsvalor) tiempoAlerta,
                     to_number(t1.dsvalor) tiempoLimite
              from tzfw_control_provisional t, tzfw_parametros t1, tzfw_parametros t2, tzfw_formularios t3
              where t1.dsparametro =''TIEMPOPROVISIONAL''
              and t2.dsparametro =''NOTIFICA_TIEMPO_PROVISIONAL''
              and t.cdcia_usuaria = t3.cdcia_usuaria
              and t.nmformulario_zf = t3.nmformulario_zf
              and (round(24 * (sysdate - t.feaprobacion),2) > to_number(t1.dsvalor)
--               or round(24 * (sysdate - t.feaprobacion),2) between to_number(t2.dsvalor) and to_number(t1.dsvalor))
               or round(24 * (sysdate - t.feaprobacion),2) > to_number(t2.dsvalor) )
              and (t1.dsValor > 0 or t2.dsvalor > 0)
               and t3.cdestado not in(''4'',''A'') ' ||CondicionFiltro$;

    oclbXML := dbms_xmlgen.getXML(vchXQuery);

    --fvchBloqueoCompania(ivchCia);
return;
end XControlTiempoProvisional;
------------------------------------------------------XCnsltaMovCamiones.prc-----------------------------------------------------------
procedure XCnsltaMovCamiones(
    ivchFilter                      in      varchar2,
    oclbXML                         out     clob)
is
    vchFilter                       varchar2(1024);
    vchXQuery                       varchar2(4600);
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
    function CondicionFiltro$
    return varchar2
    is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;
--=====================================================================================================================
begin
/****************************************************************************************

    3.0        20190301    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles 
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
*****************************************************************************************/
    vchFilter := ivchFilter;
    vchXQuery := 'select '
              || 't.cdplaca, '
              || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso , '
              || 't.cdcia_usuaria, '
              || 'to_char(t.nmtransito_documento) nmtransito_documento, '
              || 'nvl(t.cdtipo_documento,'' '') cdtipo_documento, '
              || 'nvl((select i.dstipo_ingreso from TZFW_TIPOS_INGRESO i where t.cdtipo_documento = i.cdtipo_ingreso ),'' '') dstipo_documento, '
              || 'nvl(to_char(t.nmtotal_doctransporte),''0'') nmtotal_doctransporte, '
              || 'nvl(t.nmdoctransporte, '' '') nmdoctransporte, '
              || 'nvl(t.nmtransito , '' '') nmtransito, '
              || 'nvl(to_char(t.nmtotal_contenedor),''0'') nmtotal_contenedor, '
              || 'nvl(to_char(t.nmtotal_cont_x_camion ),''0'') nmtotal_cont_x_camion, '
              || 'nvl(t.cdaduana,'' '') cdaduana, '
              || 'nvl((select a.dsaduana  from TZFW_ADUANAS_PARTIDA a where t.cdaduana  = a.cdaduana  ),'' '') dsaduana, '
              || 'nvl(to_char(t.fedesde ,''yyyy-mm-dd hh24:mi:ss''),'' '') fedesde , '
              || 'nvl(to_char(t.fehasta ,''yyyy-mm-dd hh24:mi:ss''),'' '') fehasta , '
              || 'nvl(t.cdtipo_desprecinto,'' '') cdtipo_desprecinto, '
              || 'nvl(t.snrecibo,'' '') snrecibo, '
              || 'nvl(t.cdusuario_recibo, '' '') cdusuario_recibo, '
              || 'nvl(to_char(t.ferecibo,''yyyy-mm-dd hh24:mi:ss''),'' '') ferecibo, '
              || 't.sncierre, '
              || 'nvl(t.dscausal_operacion,'' '') dscausal_operacion, '
              || 'nvl(t.sninconsistencia,'' '') sninconsistencia, '
              || 'decode(t.sninconsistencia,''N'',''NO'',''S'',''SI'','' '') dsinconsistencia, '
              || 't.id, '
              || 'nvl(t.cdusuario_aud,'' '') cdusuario_aud, '
              || 'nvl(t.sngranvolumen,'' '') sngranvolumen, '
              || 'nvl((select nvl(t.snparcial,''N'')  from   tzfw_transitos_documentos td, tzfw_documentos_x_cia t where  td.cdplaca = t.cdplaca '
              || 'AND td.feingreso = t.feingreso AND td.cdcia_usuaria = t.cdcia_usuaria   '
              || 'AND rownum=1  '||CondicionFiltro$ ||  ' ),''N'') snparcial, '
              || 'nvl(sngranel_nal,''N'') sngranel_nal, '
              || 'nvl(SNAUTORIZA,''N'') SNAUTORIZA, '
              || 'nvl(to_char(t.FEAUTORIZA ,''yyyy-mm-dd hh24:mi:ss''),'' '') FEAUTORIZA,  '
              || 'nvl(t.CDUSUARIO_AUTORIZA,'' '') CDUSUARIO_AUTORIZA, '
              || 'nvl(t0.CDTIPODESPRECINTE,'' '') CDTIPODESPRECINTE, '
              || 'nvl(t0.DSCOMENTARIODESPRE,'' '') DSCOMENTARIODESPRE '
              || 'from tzfw_camiones t0,  TZFW_TRANSITOS_DOCUMENTOS t, '
              || '       TZFW_CIAS_X_CAMION c '
              || 'where t.cdplaca   = c.cdplaca  '
              ||' and t0.cdplaca = t.cdplaca '
              ||' and t0.feingreso = t.feingreso '
              || 'and   t.feingreso = c.feingreso '
              || 'and   t.cdcia_usuaria = c.cdcia_usuaria '||CondicionFiltro$;
    --dbms_output.put_line(vchXQuery);
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XCnsltaMovCamiones;
------------------------------------------------------XEntrdasRegIngreso.prc-----------------------------------------------------------
procedure XEntrdasRegIngreso(
    ivchFilter                      in      varchar2,
    ivchTransito                    in      varchar2,
    oclbXML                         out     clob)
is
    vchFilter                       varchar2(1024);
    vchXQuery                       varchar2(4500);
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
    function CondicionFiltro$
    return varchar2
    is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;
--=====================================================================================================================
begin
/****************************************************************************************
    3.0        20190301    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles 
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
*****************************************************************************************/
    vchFilter := ivchFilter;
    vchXQuery := 'select '
              || 't.cdplaca, '
              || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso , '
              || 't.cdcia_usuaria, '
              || 'to_char(t.nmtransito_documento) nmtransito_documento, '
              || 'nvl(t.cdtipo_documento,'' '') cdtipo_documento, '
              || 'nvl((select i.dstipo_ingreso from TZFW_TIPOS_INGRESO i where t.cdtipo_documento = i.cdtipo_ingreso ),'' '') dstipo_documento, '
              || 'nvl(to_char(t.nmtotal_doctransporte),'' '') nmtotal_doctransporte, '
              || 'nvl(t.nmdoctransporte,'' '') nmdoctransporte, '
              || 'nvl(t.nmtransito , '' '') nmtransito, '
              || 'nvl(to_char(t.nmtotal_contenedor),'' '') nmtotal_contenedor, '
              || 'nvl(to_char(t.nmtotal_cont_x_camion ),'' '') nmtotal_cont_x_camion, '
              || 'nvl(t.cdaduana,'' '') cdaduana, '
              || 'nvl(to_char(t.fedesde ,''yyyy-mm-dd hh24:mi:ss''),'' '') fedesde , '
              || 'nvl(to_char(t.fehasta ,''yyyy-mm-dd hh24:mi:ss''),'' '') fehasta , '
              || 'nvl(t.cdtipo_desprecinto,'' '') cdtipo_desprecinto, '
              || 'nvl(t.snrecibo,'' '') snrecibo, '
              || 'nvl(t.cdusuario_recibo,'' '') cdusuario_recibo, '
              || 'nvl(to_char(t.ferecibo,''yyyy-mm-dd hh24:mi:ss''),'' '') ferecibo , '
              || 't.sncierre, '
              || 'nvl(t.dscausal_operacion,'' '') dscausal_operacion, '
              || 'nvl(t.sninconsistencia,'' '') sninconsistencia,'
              || 't.id, '
              || '0 valreg, '
              || 'nvl(t.cdusuario_aud,'' '') cdusuario_aud, '
              || 'nvl(sngranvolumen,''N'') sngranvolumen, '
              || 'nvl((select nvl(t.snparcial,''N'')  from   tzfw_transitos_documentos td, tzfw_documentos_x_cia t where  td.cdplaca = t.cdplaca '
              || 'AND td.feingreso = t.feingreso AND td.cdcia_usuaria = t.cdcia_usuaria AND td.nmtransito_documento = t.nmtransito_documento  '
              || 'AND rownum=1  '||CondicionFiltro$ ||  ' ),''N'') snparcial, '
              || 'nvl(sngranel_nal,''N'') sngranel_nal, '
              || 'nvl(SNAUTORIZA,''N'') SNAUTORIZA, '
              || 'nvl(t.CDUSUARIO_AUTORIZA,'' '') CDUSUARIO_AUTORIZA, '
              || 'nvl(to_char(t.FEAUTORIZA ,''yyyy-mm-dd hh24:mi:ss''),'' '') FEAUTORIZA  '
              || 'from   TZFW_TRANSITOS_DOCUMENTOS t, '
              || '       TZFW_CIAS_X_CAMION c '
              || ' where t.cdplaca   = c.cdplaca  '
              || 'and   t.feingreso = c.feingreso '
              || 'and   t.cdcia_usuaria = c.cdcia_usuaria '||CondicionFiltro$
              || 'and   instr('||''''||ivchTransito||''
              || ''', t.cdtipo_documento) = 0 ';
           dbms_output.put_line(vchXQuery);
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XEntrdasRegIngreso;
------------------------------------------------------XEntrdasRegTransitos.prc-----------------------------------------------------------
procedure XEntrdasRegTransitos(
    ivchFilter                      in      varchar2,
    ivchTransito                    in      varchar2,
    oclbXML                         out     clob)
is
    vchFilter                       varchar2(1024);
    vchXQuery                       varchar2(2048);
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
    function CondicionFiltro$
    return varchar2
    is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;
--=====================================================================================================================
begin
    vchFilter := ivchFilter;
    vchXQuery := 'select '
              || 't.cdplaca, '
              || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso , '
              || 't.cdcia_usuaria, '
              || 'to_char(t.nmtransito_documento) nmtransito_documento, '
              || 'nvl(t.cdtipo_documento,'' '') cdtipo_documento, '
              || 'nvl((select i.dstipo_ingreso from TZFW_TIPOS_INGRESO i where t.cdtipo_documento = i.cdtipo_ingreso ),'' '') dstipo_documento, '
              || 'nvl(to_char(t.nmtotal_doctransporte),'' '') nmtotal_doctransporte, '
              || 'nvl(t.nmdoctransporte,'' '') nmdoctransporte, '
              || 'nvl(t.nmtransito , '' '') nmtransito, '
              || 'nvl(to_char(t.nmtotal_contenedor),'' '') nmtotal_contenedor, '
              || 'nvl(to_char(t.nmtotal_cont_x_camion ),'' '') nmtotal_cont_x_camion, '
              || 'nvl(t.cdaduana,'' '') cdaduana, '
              || 'nvl((select a.dsaduana  from TZFW_ADUANAS_PARTIDA a where t.cdaduana  = a.cdaduana  ),'' '') dsaduana, '
              || 'nvl(to_char(t.fedesde ,''yyyy-mm-dd hh24:mi:ss''),'' '') fedesde , '
              || 'nvl(to_char(t.fehasta ,''yyyy-mm-dd hh24:mi:ss''),'' '') fehasta , '
              || 'nvl(t.cdtipo_desprecinto,'' '') cdtipo_desprecinto, '
              || 'decode(t.cdtipo_desprecinto,''F'',''FISICO'',''A'',''AUTOMATICO'','' '') dstipo_desprecinto, '
              || 'nvl(t.snrecibo,'' '') snrecibo, '
              || 'nvl(t.cdusuario_recibo,'' '') cdusuario_recibo, '
              || 'nvl(to_char(t.ferecibo,''yyyy-mm-dd hh24:mi:ss''),'' '') ferecibo , '
              || 't.sncierre, '
              || 'nvl(t.dscausal_operacion,'' '') dscausal_operacion, '
              || 'nvl(t.sninconsistencia,'' '') sninconsistencia,'
              || 't.id, '
              || '0 valreg, '
              || 'nvl(t.cdusuario_aud,'' '') cdusuario_aud, '
              ||' nvl(sngranvolumen,''N'') sngranvolumen, '
              || 'nvl(SNAUTORIZA,''N'') SNAUTORIZA, '
              || 'nvl(t.CDUSUARIO_AUTORIZA,'' '') CDUSUARIO_AUTORIZA, '
              || 'nvl(t0.CDTIPODESPRECINTE,'' '') CDTIPODESPRECINTE, '
              || 'nvl(t0.DSCOMENTARIODESPRE,'' '') DSCOMENTARIODESPRE, '
              || 'nvl(to_char(t.FEAUTORIZA ,''yyyy-mm-dd hh24:mi:ss''),'' '') FEAUTORIZA  '
              || 'from   tzfw_camiones t0,TZFW_TRANSITOS_DOCUMENTOS t, '
              || '       TZFW_CIAS_X_CAMION c '
              || ' where t0.cdplaca = t.cdplaca '
              ||' and t0.feingreso = t.feingreso '
              ||' and t.cdplaca   = c.cdplaca  '
              || 'and   t.feingreso = c.feingreso '
              || 'and   t.cdcia_usuaria = c.cdcia_usuaria '||CondicionFiltro$
              || 'and   instr('||''''||ivchTransito||''
              || ''', t.cdtipo_documento) > 0 ';
dbms_output.put_line(vchXQuery);              
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XEntrdasRegTransitos;
------------------------------------------------------XUsuClficadoCnslta.prc-----------------------------------------------------------
procedure XUsuClficadoCnslta(
    ivchFilter                      in      varchar2,
    oclbXML                         out     clob)
is
    vchFilter                       varchar2(1024);
    vchXQuery                       varchar2(2048);
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
    function CondicionFiltro$
    return varchar2
    is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;
--=====================================================================================================================
begin
    vchFilter := ivchFilter;
    vchXQuery := 'select '
              || 't.cdplaca, '
              || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso, '
              || 't.cdcia_usuaria, '
              || 'to_char(t.nmtransito_documento) nmtransito_documento, '
              || 'nvl(t.cdtipo_documento,'' '') cdtipo_documento, '
              || 'nvl((select i.dstipo_ingreso from TZFW_TIPOS_INGRESO i where t.cdtipo_documento = i.cdtipo_ingreso ),'' '') dstipo_documento, '
              || 'nvl(to_char(t.nmtotal_doctransporte),''0'') nmtotal_doctransporte, '
              || 'nvl(t.nmdoctransporte,'' '') nmdoctransporte, '
              || 'nvl(t.nmtransito , '' '') nmtransito, '
              || 'nvl(to_char(t.nmtotal_contenedor),''0'') nmtotal_contenedor, '
              || 'nvl(to_char(t.nmtotal_cont_x_camion ),''0'') nmtotal_cont_x_camion, '
              || 'nvl(t.cdtipo_desprecinto,'' '') cdtipo_desprecinto, '
              || 'decode(t.cdtipo_desprecinto,''F'',''FISICO'',''A'',''AUTOMATICO'','' '') dstipo_desprecinto, '
              || 't.sncierre, '
              || 'decode(t.sncierre,''N'',''NO'',''S'',''SI'') dscierre, '
              || 't.id '
              || 'from   TZFW_TRANSITOS_DOCUMENTOS t, '
              || '       TZFW_CIAS_X_CAMION c '
              || 'where t.cdplaca   = c.cdplaca  '
              || 'and   t.feingreso = c.feingreso '
              || 'and   t.cdcia_usuaria = c.cdcia_usuaria '||CondicionFiltro$;
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XUsuClficadoCnslta;
------------------------------------------------------XUsuClficadoInvntrio.prc-----------------------------------------
procedure XUsuClficadoInvntrio(
    ivchFilter                      in      varchar2,
    ivchTransito                    in      varchar2,
    oclbXML                         out     clob)
is
    vchFilter                       varchar2(1024);
    vchXQuery                       varchar2(2048);
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
    function CondicionFiltro$
    return varchar2
    is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;
--=====================================================================================================================
begin
    vchFilter := ivchFilter;
    vchXQuery := 'select '
              || 't.cdplaca, '
              || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso, '
              || 't.cdcia_usuaria, '
              || 'to_char(t.nmtransito_documento) nmtransito_documento, '
              || 'nvl(t.cdtipo_documento,'' '') cdtipo_documento, '
              || 'nvl((select i.dstipo_ingreso from TZFW_TIPOS_INGRESO i where t.cdtipo_documento = i.cdtipo_ingreso ),'' '') dstipo_documento, '
              || 'nvl(to_char(t.nmtotal_doctransporte),''0'') nmtotal_doctransporte, '
              || 'nvl(t.nmdoctransporte,'' '') nmdoctransporte, '
              || 'nvl(t.nmtransito , '' '') nmtransito, '
              || 'nvl(to_char(t.nmtotal_contenedor),''0'') nmtotal_contenedor, '
              || 'nvl(to_char(t.nmtotal_cont_x_camion ),''0'') nmtotal_cont_x_camion, '
              || 'nvl(t.cdtipo_desprecinto,'' '') cdtipo_desprecinto, '
              || 'decode(t.cdtipo_desprecinto,''F'',''FISICO'',''A'',''AUTOMATICO'','' '') dstipo_desprecinto, '
              || 't.sncierre, '
              || 'decode(t.sncierre,''N'',''NO'',''S'',''SI'') dscierre, '
              || 't.id '
              || 'from   TZFW_TRANSITOS_DOCUMENTOS t, '
              || '       TZFW_CIAS_X_CAMION c '
              || 'where t.cdplaca   = c.cdplaca  '
              || 'and   t.feingreso = c.feingreso '
              || 'and   t.cdcia_usuaria = c.cdcia_usuaria '||CondicionFiltro$
              || 'and   instr('||''''||ivchTransito||''
              || ''', t.cdtipo_documento) > 0 ';
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XUsuClficadoInvntrio;
------------------------------------------------------XUsuClficadoRegDoc.prc-----------------------------------------
procedure XUsuClficadoRegDoc(
    ivchFilter                      in      varchar2,
    oclbXML                         out     clob)
is
    vchFilter                       varchar2(1024);
    vchXQuery                       varchar2(4000);
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
    function CondicionFiltro$
    return varchar2
    is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;
--=====================================================================================================================
begin
    vchFilter := ivchFilter;
    vchXQuery := 'select '
              || 't.cdplaca, '
              || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso, '
              || 't.cdcia_usuaria, '
              || 'to_char(t.nmtransito_documento) nmtransito_documento, '
              || 'nvl(t.cdtipo_documento,'' '') cdtipo_documento, '
              || 'nvl((select i.dstipo_ingreso from TZFW_TIPOS_INGRESO i where t.cdtipo_documento = i.cdtipo_ingreso ),'' '') dstipo_documento, '
              || 'nvl(to_char(t.nmtotal_doctransporte),''0'') nmtotal_doctransporte, '
              || 'nvl(t.nmdoctransporte,'' '') nmdoctransporte, '
              || 'nvl(t.nmtransito , '' '') nmtransito, '
              || 'nvl(to_char(t.nmtotal_contenedor),''0'') nmtotal_contenedor, '
              || 'nvl(to_char(t.nmtotal_cont_x_camion ),''0'') nmtotal_cont_x_camion, '
              || 'nvl(t.cdtipo_desprecinto,'' '') cdtipo_desprecinto, '
              || 'decode(t.cdtipo_desprecinto,''F'',''FISICO'',''A'',''AUTOMATICO'','' '') dstipo_desprecinto, '
              || 't.sncierre, '
              || 'nvl(t1.nacional,''N'')nacional,'
              || 'nvl(t1.planilla_recepcion,''N'') planilla_recepcion,'
              || 'decode(t.sncierre,''N'',''NO'',''S'',''SI'') dscierre, '
              || 't.id,nvl(t2.cdestado,''NA'') cdestado, nvl(nmplanilla,'' '')nmplanilla,nvl(dsplanilla,'' '')dsplanilla, '
              || 'nvl(t0.CDTIPODESPRECINTE,'' '') CDTIPODESPRECINTE, '
              || 'nvl(t0.DSCOMENTARIODESPRE,'' '') DSCOMENTARIODESPRE '
              || 'from tzfw_camiones t0,  TZFW_TRANSITOS_DOCUMENTOS t, '
              || '       TZFW_CIAS_X_CAMION c, '
              || ' tzfw_tipos_ingreso t1,tzfw_estados_planilla t2 '
              || 'where t.cdplaca   = c.cdplaca  '
              ||' and t.cdplaca = t0.cdplaca '
              ||' and t.feingreso = t0.feingreso '
              || 'and   t.feingreso = c.feingreso '
              || 'and   t.cdtipo_documento = t1.cdtipo_ingreso(+) '
              ||'and   t.cdplaca = t2.cdplaca(+) '
              ||'and   t.cdcia_usuaria = t2.cdcia_usuaria(+) '
              ||'and   t.feingreso =t2.feingreso(+) '
              ||'and t.nmtransito_documento = t2.nmtransito_documento(+) '
              || 'and   t.cdcia_usuaria = c.cdcia_usuaria '||CondicionFiltro$;
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XUsuClficadoRegDoc;
--------------------------------------------------------------------------------------------
procedure Query$Definitivo(inmbFormulario_zf in  tzfw_formularios.nmformulario_zf%type,
                           vchCiaUsuaria     in  tzfw_formularios.cdcia_usuaria%type,
                           oclbXML                         out     clob)
is
   vchValor     tzfw_parametros.dsvalor%type;
   vchXQuery                       varchar2(2048);
begin
 /*  select ''''||replace(dsvalor,' ',''',''')||'''' valor
   into vchValor
   from tzfw_parametros
   where dsparametro='OTROS_INGRESOS';*/

   vchXQuery := 'select count(distinct nmformulario_zf) total '||
   ' from tzfw_formularios t2 '||
   ' where t2.nmformulario_zf = '''||inmbFormulario_zf||''''||
   ' and t2.cdcia_usuaria ='''||vchCiaUsuaria||''''||
   ' and t2.cdtipo  in(''2'',''1'')';
   oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;

end Query$Definitivo;
--------------------------------------------------------------------------------------------
procedure Query$Definitivo$(inmbFormulario_zf in  tzfw_formularios.nmformulario_zf%type,
                           vchCiaUsuaria     in  tzfw_formularios.cdcia_usuaria%type,
                           onmbRta           out     number)
is
   vchXQuery                       varchar2(2048);
begin

  /* select count(distinct nmformulario_zf) total
   into onmbRta
    from tzfw_transitos_documentos t, TZFW_TIPOS_INGRESO t1, tzfw_formularios t2
    where t.cdtipo_documento = t1.cdtipo_ingreso
    and t1.cdtipo_ingreso in(select replace(dsvalor,' ',',')
                             from tzfw_parametros
                             where dsparametro='OTROS_INGRESOS')
    and t2.nmformulario_zf =inmbFormulario_zf
    and t2.cdcia_usuaria =vchCiaUsuaria
    and t2.cdtipo not in('2','1');*/

    select count(distinct nmformulario_zf) total
    into onmbRta
    from tzfw_formularios t2
    where t2.nmformulario_zf =inmbFormulario_zf
    and t2.cdcia_usuaria =vchCiaUsuaria
    and t2.cdtipo not in('2','1');
    return;

end Query$Definitivo$;
--------------------------------------------------------------------------------------------
procedure Query$Formulario$Dup(inmbFormulario_zf in  tzfw_formularios.nmformulario_zf%type,
                           ivchCiaUsuaria     in  tzfw_formularios.cdcia_usuaria%type,
                           ivchPlaca          in tzfw_transitos_documentos.cdplaca%type,
                           idtFeIngreso       in tzfw_transitos_documentos.feingreso%type,
                           inmbTransito       in tzfw_transitos_documentos.nmtransito_documento%type,
                           ivchTipo           in tzfw_transitos_documentos.cdtipo_documento%type,
                           inmbId            in  tzfw_formularios.id%type,
                           oclbXML                         out     clob)
is
   vchXQuery                       varchar2(2048);
begin

   vchXQuery := 'select count(1) total '||
   ' from tzfw_documentos_x_cia t '||
   ' where t.nmformulario_zf = '''||inmbFormulario_zf||''''||
   ' and t.cdcia_usuaria ='''||ivchCiaUsuaria||''''||
   ' and t.nmformulario_zf in(select t1.nmformulario_zf
                             from tzfw_transitos_documentos t0, tzfw_documentos_x_cia t1
                             where t0.cdplaca = t1.cdplaca
                             and t0.feingreso = t1.feingreso
                             and t0.cdcia_usuaria = t1.cdcia_usuaria
                             and t0.nmtransito_documento = t1.nmtransito_documento
                             and t0.cdtipo_documento != '''||ivchTipo||'''
                             and t0.cdcia_usuaria = '''||ivchCiaUsuaria||''')';

   if inmbId is not null then
      vchXQuery := vchXQuery||' and t.id != '||inmbid;
   end if;
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;

end Query$Formulario$Dup;
--------------------------------------------------------------------------------------------
procedure Query$Formulario$Dup$(inmbFormulario_zf in  tzfw_formularios.nmformulario_zf%type,
                           ivchCiaUsuaria     in  tzfw_formularios.cdcia_usuaria%type,
                           ivchPlaca          in tzfw_transitos_documentos.cdplaca%type,
                           idtFeIngreso       in tzfw_transitos_documentos.feingreso%type,
                           inmbTransito       in tzfw_transitos_documentos.nmdoctransporte%type,
                           onmbTotal          out     number)
is
   ivchTipo tzfw_transitos_documentos.cdtipo_documento%type;
   total    number;
begin

/****************************************************************************************
    REVISION:
    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------
    4.0        20190517    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              acuerdo a lo indicado en el bug 8:
                                              En la pantalla de usuario calificado registro 
                                              sale error cuando se hace click sobre el boton
                                              CARGAR EXCEL.
                                              Se coloca el manejo de excepciones para controlar 
                                              el error que sale.
*****************************************************************************************/
  -- validar si existe para el mismo formulario mas de un tipo de ingreso
    -- consultar el tipo de ingreso del transito
    begin
        select distinct cdtipo_documento
        into ivchTipo
        from tzfw_transitos_documentos t
        where nvl(nmtransito,t.nmdoctransporte) = inmbTransito
        and   cdcia_usuaria = ivchCiaUsuaria;
    exception
      when no_data_found then return; 
      when others then return; 
    end;

   -- consultar si existe otro registro asociado a otro documento / transito diferente
   select count(1)
   into total
   from tzfw_transitos_documentos t , tzfw_documentos_x_cia t1
   where t.cdcia_usuaria = t1.cdcia_usuaria
   and t.nmtransito_documento = t1.nmtransito_documento
   and t1.nmformulario_zf=inmbFormulario_zf
   and t1.cdcia_usuaria = ivchCiaUsuaria
   and nvl(nmtransito,t.nmdoctransporte) != inmbTransito;

    if (total > 0 ) then onmbTotal :=161; end if;

    return;

end Query$Formulario$Dup$;
------------------------------------------------------XVerificarTransito.prc-----------------------------------------------------------
procedure XVerificarTransito(
    ivchFilter                      in      varchar2,
    ivchTransito                    in      varchar2,
    oclbXML                         out     clob)
is
    vchFilter                       varchar2(1024);
    vchXQuery                       varchar2(2048);
--------------------------------------------------CondicionFiltro$-----------------------------------------------------
    function CondicionFiltro$
    return varchar2
    is
    begin
        vchFilter := replace(vchFilter,'?','''');
        vchFilter := replace(vchFilter,'[','<');
        vchXQuery := null;
        if (vchfilter is null) then return(vchXQuery); end if;
        return(vchfilter);
    end CondicionFiltro$;
--=====================================================================================================================
begin
    vchFilter := ivchFilter;
    vchXQuery := 'select '
              || 't.cdplaca, '
              || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso , '
              || 't.cdcia_usuaria, '
              || 'c.dscia_usuaria, '
              || 'to_char(t.nmtransito_documento) nmtransito_documento, '
              || 'nvl(t.cdtipo_documento,'' '') cdtipo_documento, '
              || 'nvl((select i.dstipo_ingreso from TZFW_TIPOS_INGRESO i where t.cdtipo_documento = i.cdtipo_ingreso ),'' '') dstipo_documento, '
              || 'nvl(to_char(t.nmtotal_doctransporte),''0'') nmtotal_doctransporte, '
              || 'nvl(t.nmdoctransporte, '' '') nmdoctransporte, '
              || 'nvl(t.nmtransito , '' '') nmtransito, '
              || 'nvl(to_char(t.nmtotal_contenedor),''0'') nmtotal_contenedor, '
              || 'nvl(to_char(t.nmtotal_cont_x_camion ),''0'') nmtotal_cont_x_camion, '
              || 'nvl(t.cdaduana,'' '') cdaduana, '
              || 'nvl((select a.dsaduana  from TZFW_ADUANAS_PARTIDA a where t.cdaduana  = a.cdaduana  ),'' '') dsaduana, '
              || 'nvl(to_char(t.fedesde ,''yyyy-mm-dd hh24:mi:ss''),'' '') fedesde , '
              || 'nvl(to_char(t.fehasta ,''yyyy-mm-dd hh24:mi:ss''),'' '') fehasta , '
              || 'nvl(t.cdtipo_desprecinto,'' '') cdtipo_desprecinto, '
              || 'nvl(t.snrecibo,'' '') snrecibo, '
              || 'nvl(t.cdusuario_recibo, '' '') cdusuario_recibo, '
              || 'nvl(to_char(t.ferecibo,''yyyy-mm-dd hh24:mi:ss''),'' '') ferecibo, '
              || 't.sncierre, '
              || 'nvl(t.dscausal_operacion,'' '') dscausal_operacion, '
              || 'nvl(t.sninconsistencia,'' '') sninconsistencia, '
              || 't.id, '
              || 'nvl(t.cdusuario_aud,'' '') cdusuario_aud '
              || 'from   TZFW_TRANSITOS_DOCUMENTOS t, '
              || '       TZFW_CIA_USUARIAS c '
              || 'where  t.cdcia_usuaria = c.cdcia_usuaria '
              || 'and instr('||''''||ivchTransito||''
              || ''', t.cdtipo_documento) > 0 '||CondicionFiltro$;
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end XVerificarTransito;

------------------------------------------------------XQUERYTIPOTRANSITO.PRC-----------------------------------------
PROCEDURE XqueryTipoTransito(
    INMTRANSITO_DOCUMENTO           IN      VARCHAR2,
    OCLBXML                         OUT     CLOB)
IS
    VCHXQUERY                       VARCHAR2(2048);
    VTRANSITO                       VARCHAR2(20);
BEGIN

    SELECT DSVALOR INTO VTRANSITO FROM TZFW_PARAMETROS WHERE DSPARAMETRO = 'TRANSITO';

    VCHXQUERY := 'SELECT '
              || 'COUNT(0)TOTAL '
              || 'FROM   TZFW_TRANSITOS_DOCUMENTOS TD INNER JOIN TZFW_TIPOS_INGRESO TI '
              || 'ON TD.CDTIPO_DOCUMENTO = TI.CDTIPO_INGRESO '
              || 'WHERE instr('''||VTRANSITO||''',td.cdtipo_documento)= 0 '
              || 'AND TD.NMTRANSITO_DOCUMENTO=''' || INMTRANSITO_DOCUMENTO || ''' ';
    DBMS_OUTPUT.PUT_LINE(VCHXQUERY);
    OCLBXML := DBMS_XMLGEN.GETXML(VCHXQUERY);
    DBMS_OUTPUT.PUT_LINE(OCLBXML);
    RETURN;
END XqueryTipoTransito;

---------------------------------------------------------- XQuery$FeDigitalizacion.prc -----------------------------------------------
/*procedure XQuery$FeDigitalizacion(
    icdcia_usuaria          in TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type,
    icdplaca                in TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type,
    ifedigitalizacion       IN TZFW_TRANSITOS_DOCUMENTOS.FEDIGITALIZACION%type,
    clbXML                  out   clob)
is

 vchXQuery                  VARCHAR2(2048);

begin
    vchXQuery := 'SELECT '
              || 'COUNT(*)CANTIDAD '
              || 'from TZFW_TRANSITOS_DOCUMENTOS TD '
              || 'WHERE TD.CDCIA_USUARIA ='''||icdcia_usuaria||''' '
              ||' AND   TD.CDPLACA = ''' || icdplaca || ''' '
              ||' AND   TD.FEINGRESO = ''' || ifedigitalizacion || ''' ';

    clbXML := dbms_xmlgen.getXML(vchXQuery);

    RETURN;
end XQuery$FeDigitalizacion;
*/

-----------------------------------------------------------------------------------
procedure QryNotifDocRechaSuspe(
    onmbErr                         out     number,
    ovchErrMsg                      out     varchar2,
    icdcia_usuaria                   in     varchar2,    
    icd_usuario                      in      varchar2,
    onmbAprobado                    out     number,
    oclbXML                         out     clob)
/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------
    1.0                                       creacion del paquete
    2.0        20181214    Guillermo Prieto   Modificacion del paquete para incluir el procedimiento
                                              de las notificaciones
                                              acuerdo a lo solicitado en el req 3 Notificacion por
                                              cambio a estado Suspendido del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Cada vez que se Rechace una planilla o un Formulario de Movimiento de Mercancia,
                                              a los usuarios del sistema de la compania a la que pertenece la placa y/o
                                              el formulario le debe llegar la notificacion del rechazo, en la cual debe aparecer:
                                              Suspendida: Placa XXX, documento (planilla o transito) XXXX. fecha y hora de rechazo.
                                              (si es placa para planilla de recepcion).
                                              Rechazado: Formulario ####. fecha y hora de rechazo.(si es Formulario de movimiento
                                              de mercancia).
     5.0        20191028    Guillermo Prieto  Modificacion del paquete para modificar el procedimiento
                                              para consultar la informacion de los formularios rechazados y
                                              placas suspendidas de la tabla de notificacion de eventos, 
                                              de acuerdo a lo solicitado en la nueva definicion del req 3 de notificacones
                                              que estaba especificado en el documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              y que se cambia de acuerdo a reuniones realizadas con Leandro Santamaria
                                              que las notificaciones deben ser mas abiertas no solo para formularios
                                              rechazados y placas suspendidas, que se puedan ingresar otras notificaciones
                                              para esto se va a guardar la informacion en la base de datos. dllo06  cc15

      6.0        20191128    Guillermo Prieto  Modificacion del paquete para modificar el procedimiento
                                              para consultar las notificaciones de formularios de importacion 
                                              de la tabla de notificacion de eventos, adicionanado la tabla no notificar a
                                              usuarios y agregar el campo identificacion en el filtro de las notificaciones 
                                              si este campo viene con algun valor, si no trae valor se consultan todas
                                              las notificaciones para que se puedan ingresar otras notificaciones
                                              para esto se va a guardar la informacion en la base de datos. dllo05  cc3

*****************************************************************************************/

is
   nmbValor                     number  :=0;
   vchXQuery                    varchar2(6000) :=Null;
   vchcdcia_usuaria             tzfw_documentos_x_cia.CDCIA_USUARIA%type;
   vchcdidentificacion          tzfw_usuarios.CDIDENTIFICACION%type := ' ';

begin
   vchcdcia_usuaria := icdcia_usuaria;
 --  vchcdidentificacion := ivchcdidentificacion;

   -- si existen registros con la compania realiza la consulta para mostrar las notificaciones 
   -- desde la tabla notificaciones de eventos 

   -- si existen registros con la compania realiza la consulta para mostrar las notificaciones 
   -- desde la tabla notificaciones de eventos 
   -- si existen registros con la compania realiza la consulta para mostrar las notificaciones 
   -- desde la tabla notificaciones de eventos 
   -- si APROABADO es 0 esta SIN APROBAR, si APROABADO es 1 esta APROBADO 
  -- if (vchcdcia_usuaria is not null)then
       select sum(total_reg)
         into nmbValor
         from
              (
               select count(0) total_reg
                 from tzfw_notificac_eventos ne
                where ne.cdestado_evento='A') x;


      vchXQuery := 'select ne.dsmensaje, ne.feestado_evento, ne.id, ne.dsevento, ne.feevento, ne.dselemento, ne.cdelemento, '
                 || 'ne.idelemento, ne.cdcia_usuaria, ne.dsestado, ne.cdestado_evento, ne.cdidentificacion, ne.dsdestinatarios '
                 || 'from  tzfw_notificac_eventos ne '
                 || 'where ne.cdestado_evento=''A'' '                 
              --   || 'and   ne.cdidentificacion= ' || ''''||icd_usuario||''''
                 ||' and id not in(select id_notif_event from tzfw_no_notif_usuarios t where cdidentificacion= '|| ''''||icd_usuario||''')'
                 || 'ORDER BY 2 DESC ';

       --dbms_output.put_line(vchXQuery);
       oclbXML := dbms_xmlgen.getXML(vchXQuery);
       onmbAprobado:=nmbValor;

       if (nmbValor = 0)then onmbErr:= -1;end if;

exception
    when others then
        onmbErr     := zfstzfw_admon_errores.Nmerror$$;

        if (zfstzfw_admon_errores.DsMensaje_Usuario$$ is null) then
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_bd$$||' '||objeto_error;
        else
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_Usuario$$||' '||objeto_error;
        end if;

        return;
end QryNotifDocRechaSuspe;

-----------------------------------------------------------------------------------
procedure ConsultaGranel_Nal(
    onmbErr                         out     number,
    ovchErrMsg                      out     varchar,
    ivchcdcia_usuaria                in     varchar,
    ivchnmdoctransporte              in     varchar,
    ivchcdtipo_documento             in     varchar,
    ovchsngranel_nal                out     varchar,
    oclbXML                         out     clob)
/****************************************************************************************
    3.0        20190306    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles 
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
                                              procedimiento creado para traer el valor de granel nal del primero registro
                                              existente para ese mismo tipo de numero de documento, puede retornar los valores
                                              S o N, si no existe retorna valor de -1 y en la aplicacion se tratara como N
*****************************************************************************************/

is
   nmbValor                     number  :=0;
   vchXQuery                    varchar2(6000) :=Null;
   vchcdcia_usuaria             tzfw_transitos_documentos.CDCIA_USUARIA%type;
   vchnmdoctransporte           tzfw_transitos_documentos.NMDOCTRANSPORTE%type;
   vchcdtipo_documento          tzfw_transitos_documentos.CDTIPO_DOCUMENTO%type;

begin
   vchcdcia_usuaria := ivchcdcia_usuaria;
   vchnmdoctransporte := ivchnmdoctransporte;
   vchcdtipo_documento := ivchcdtipo_documento;

   -- ConsultaGranel_Nal de la compania y del tipo de numero de documento en cuestion, devuelve S o N si existe, 
   -- sino existe devuelve -1 
   if (vchcdcia_usuaria is not null)then

      select count(0) Total_reg 
      into   nmbValor
      from   tzfw_transitos_documentos t3, tzfw_tipos_ingreso ti 
      where  t3.cdtipo_documento = ti.cdtipo_ingreso
      and    ti.nacional = 'S'
      and    t3.cdcia_usuaria = vchcdcia_usuaria
      and    t3.nmdoctransporte = vchnmdoctransporte
      and    t3.cdtipo_documento = vchcdtipo_documento;

      if nmbValor > 0 then
         select nvl(t3.sngranel_nal,'N')  SNGRANEL_NAL
         into   ovchsngranel_nal
         from   tzfw_transitos_documentos t3, tzfw_tipos_ingreso ti 
         where  t3.cdtipo_documento = ti.cdtipo_ingreso
         and    ti.nacional = 'S'
         and    t3.cdcia_usuaria = vchcdcia_usuaria
         and    t3.nmdoctransporte = vchnmdoctransporte
         and    t3.cdtipo_documento = vchcdtipo_documento
         and    rownum = 1
         order by nmtransito_documento;


         vchXQuery :=  'select  nvl(t3.sngranel_nal,''N'')  SNGRANEL_NAL  '
                    || 'from   tzfw_transitos_documentos t3, tzfw_tipos_ingreso ti   '
                    || 'where  t3.cdtipo_documento = ti.cdtipo_ingreso ' 
                    || ' and   ti.nacional = ''S'' ' 
                    || ' and   t3.cdcia_usuaria = ' || ''''||vchcdcia_usuaria||'''' 
                    || ' and   t3.nmdoctransporte =  ' || ''''||vchnmdoctransporte||''''             
                    || ' and   t3.cdtipo_documento =  ' || ''''||vchcdtipo_documento||''''             
                    || ' and   rownum = 1 '
                    || ' order by nmtransito_documento ';             

         --dbms_output.put_line(vchXQuery);
         oclbXML := dbms_xmlgen.getXML(vchXQuery);
         --onmbAprobado:=nmbValor;
       end if;

       if (nmbValor = 0)then 
           ovchsngranel_nal := -1;
           onmbErr := -1;
           oclbXML := zfx_library.fclbsetMessage2XML(ovchsngranel_nal, ' ');
       end if;
   end if;
exception
    when others then
        prcrErrRecord.Nmerror := sqlcode;

        prcrErrRecord.DsMensaje_bd := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
                                             instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

        if (prcrErrRecord.DsMensaje_bd is null) then
            prcrErrRecord.DsMensaje_bd := substr(sqlerrm,1,256);
        end if;

        objeto_error := substr(sqlerrm,instr(sqlerrm,'(') + 1, length(substr(sqlerrm,1,
                               instr(sqlerrm,')')-2)) - instr(sqlerrm,'(') + 1 );

        zfstzfw_admon_errores.filtrar_comillas(objeto_error,objeto_error);

        zfstzfw_admon_errores.Query$Nmerror(prcrErrRecord.Nmerror);

        if (not zfstzfw_admon_errores.SQL$$Found) then
                zfitzfw_admon_errores.Insert$(onmbErr,ovchErrMsg,prcrErrRecord);
        end if;

        onmbErr     := zfstzfw_admon_errores.Nmerror$$;

        if (zfstzfw_admon_errores.DsMensaje_Usuario$$ is null) then
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_bd$$||' '||objeto_error;
        else
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_Usuario$$||' '||objeto_error;
        end if;

        return;
end ConsultaGranel_Nal;


-----------------------------------------------------------------------------------
procedure ConsEntrega_Parcial(
    onmbErr                         out     number,
    ovchErrMsg                      out     varchar,
    ivchcdcia_usuaria                in     varchar,
    ivchnmdoctransporte              in     varchar,
    ivchcdtipo_documento             in     varchar,
    ovchsnparcial                   out     varchar,
    oclbXML                         out     clob)
/****************************************************************************************
    3.0        20190306    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles 
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
                                              procedimiento creado para traer el valor de entrega parcial del primero registro
                                              existente para ese mismo tipo de numero de documento, puede retornar los valores
                                              S o N, si no existe o no hay registros retorna valor de -1 y en la aplicacion se tratara como N
*****************************************************************************************/

is
   nmbValor                     number  :=0;
   vchXQuery                    varchar2(6000) :=Null;
   vchcdcia_usuaria             tzfw_transitos_documentos.CDCIA_USUARIA%type;
   vchnmdoctransporte           tzfw_transitos_documentos.NMDOCTRANSPORTE%type;
   vchcdplaca                   tzfw_transitos_documentos.CDPLACA%type;
   dtfeingreso                  tzfw_transitos_documentos.FEINGRESO%type;
   nmbnmtransito_Documento      tzfw_transitos_documentos.NMTRANSITO_DOCUMENTO%type;
   vchcdtipo_documento          tzfw_transitos_documentos.CDTIPO_DOCUMENTO%type;

begin
   vchcdcia_usuaria := ivchcdcia_usuaria;
   vchnmdoctransporte := ivchnmdoctransporte;
   vchcdtipo_documento := ivchcdtipo_documento;

   -- ConsultaGranel_Nal de la compania y del tipo de numero de documento en cuestion, devuelve S o N si existe, 
   -- sino existe devuelve -1 
   if (vchcdcia_usuaria is not null)then

      select count(0) Total_reg 
      into   nmbValor
      from   tzfw_transitos_documentos td,
             tzfw_documentos_x_cia  dc,
             tzfw_tipos_ingreso ti
      where  td.cdplaca = dc.cdplaca
      and    td.feingreso = dc.feingreso
      and    td.cdcia_usuaria = dc.cdcia_usuaria
      and    td.nmtransito_documento = dc.nmtransito_documento
      and    td.cdtipo_documento = ti.cdtipo_ingreso
      and    ti.nacional = 'S'
      and    td.cdcia_usuaria = vchcdcia_usuaria
      and    td.nmdoctransporte = vchnmdoctransporte
      and    td.cdtipo_documento = vchcdtipo_documento
      and    rownum = 1
      order by dc.nmtransito_documento, dc.nmconsecutivo_doc;

      if nmbValor > 0 then
         select nvl(dc.snparcial,'N')  SNPARCIAL
         into   ovchsnparcial
         from   tzfw_transitos_documentos td,
                tzfw_documentos_x_cia  dc,
                tzfw_tipos_ingreso ti
         where  td.cdplaca = dc.cdplaca
         and    td.feingreso = dc.feingreso
         and    td.cdcia_usuaria = dc.cdcia_usuaria
         and    td.nmtransito_documento = dc.nmtransito_documento
         and    td.cdtipo_documento = ti.cdtipo_ingreso
         and    ti.nacional = 'S'
         and    td.cdcia_usuaria = vchcdcia_usuaria
         and    td.nmdoctransporte = vchnmdoctransporte
         and    td.cdtipo_documento = vchcdtipo_documento
         and    rownum = 1
         order by dc.nmtransito_documento, dc.nmconsecutivo_doc;


         vchXQuery :=  'select  nvl(dc.snparcial,''N'')  SNPARCIAL  '
                    || 'from    tzfw_transitos_documentos td,  '
                    || 'tzfw_documentos_x_cia dc,  '
                    || 'tzfw_tipos_ingreso ti  '
                    || 'where  td.cdplaca = dc.cdplaca  ' 
                    || ' and   td.feingreso = dc.feingreso  '
                    || ' and   td.cdcia_usuaria = dc.cdcia_usuaria  '
                    || ' and   td.nmtransito_documento = dc.nmtransito_documento  '
                    || ' and   td.cdtipo_documento = ti.cdtipo_ingreso  '
                    || ' and   ti.nacional = ''S''  '
                    || ' and   td.cdcia_usuaria =  ' || ''''||vchcdcia_usuaria||''''             
                    || ' and   td.nmdoctransporte =  ' || ''''||vchnmdoctransporte||''''             
                    || ' and   td.cdtipo_documento =  ' || ''''||vchcdtipo_documento||''''             
                    || ' and   rownum = 1 '
                    || ' order by dc.nmtransito_documento, dc.nmconsecutivo_doc ';             

         --dbms_output.put_line(vchXQuery);
         oclbXML := dbms_xmlgen.getXML(vchXQuery);
         --onmbAprobado:=nmbValor;
       end if;

       if (nmbValor = 0)then 
           ovchsnparcial := -1;
           onmbErr := -1;
           oclbXML := zfx_library.fclbsetMessage2XML(ovchsnparcial, ' ');
       end if;
   end if;
exception
    when others then
        prcrErrRecord.Nmerror := sqlcode;

        prcrErrRecord.DsMensaje_bd := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
                                             instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

        if (prcrErrRecord.DsMensaje_bd is null) then
            prcrErrRecord.DsMensaje_bd := substr(sqlerrm,1,256);
        end if;

        objeto_error := substr(sqlerrm,instr(sqlerrm,'(') + 1, length(substr(sqlerrm,1,
                               instr(sqlerrm,')')-2)) - instr(sqlerrm,'(') + 1 );

        zfstzfw_admon_errores.filtrar_comillas(objeto_error,objeto_error);

        zfstzfw_admon_errores.Query$Nmerror(prcrErrRecord.Nmerror);

        if (not zfstzfw_admon_errores.SQL$$Found) then
                zfitzfw_admon_errores.Insert$(onmbErr,ovchErrMsg,prcrErrRecord);
        end if;

        onmbErr     := zfstzfw_admon_errores.Nmerror$$;

        if (zfstzfw_admon_errores.DsMensaje_Usuario$$ is null) then
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_bd$$||' '||objeto_error;
        else
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_Usuario$$||' '||objeto_error;
        end if;

        return;
end ConsEntrega_Parcial;

-----------------------------------------------------------Update$Auditoria.prc ------------------------------------------------
procedure Update$Auditoria(
    onmbErr                         out     number,
    ovchErrMsg                      out     varchar2,
    ivchruta_final                  in      tzfw_archivos_dig.vchruta_final%type,
    ivchobservacion                 in      tzfw_archivos_dig.vchobservacion%type,
    ifeoptimizacion                 in      tzfw_archivos_dig.feoptimizacion%type,
    ivchduracion_optimizado         in      varchar2,
    inmbtamano_archiv_opti          in      tzfw_archivos_dig.nmtamano_archiv_opti%type,
    inmbId                          in      tzfw_archivos_dig.id%type) 
is
   prcrRecordAud                    rtytzfw_archivos_dig;
   nmbduracion_optimizado           tzfw_archivos_dig.nmduracion_optimizado%type := 0;

begin
/****************************************************************************************
    5.0        20190605    Guillermo Prieto   Modificacion del paquete para incluir los campos para el requerimiento de 
                                              optimizacion de imagenes:
                                              - RUTA_FINAL (ubicacion del archivo optimizado)
                                              - OBSERVACION (Manejo de excepciones al optimizar, como un log) 
                                              - FECHA_OPTIMIZACION (Fecha en la que es optimizado un archivo)
                                              - DURACION_OPTIMIZADO (Tiempo en que tarda completar la optimizacion de un archivo)
                                              - TAMANO_ARCHIV_ORIG
                                              - TAMANO_ARCHIV_OPTI                                              
                                              de acuerdo al documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
*****************************************************************************************/
   --prcrRecordAud := ircrRecord;

    nmbduracion_optimizado := To_Number(ivchduracion_optimizado);

    UPDATE tzfw_archivos_dig ad
    SET    ad.vchruta_final           =  ivchruta_final,
           ad.vchobservacion          =  ivchobservacion,
           ad.feoptimizacion          =  ifeoptimizacion,
           ad.nmduracion_optimizado   =  nmbduracion_optimizado,
           ad.nmtamano_archiv_opti    =  inmbtamano_archiv_opti
    WHERE  ad.id                      =  inmbId;
    COMMIT;

    return;
exception
    when others then
        prcrErrRecord.Nmerror := sqlcode;

        prcrErrRecord.DsMensaje_bd := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
                                             instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

        if (prcrErrRecord.DsMensaje_bd is null) then
            prcrErrRecord.DsMensaje_bd := substr(sqlerrm,1,256);
        end if;

        objeto_error := substr(sqlerrm,instr(sqlerrm,'(') + 1, length(substr(sqlerrm,1,
                               instr(sqlerrm,')')-2)) - instr(sqlerrm,'(') + 1 );

        zfstzfw_admon_errores.filtrar_comillas(objeto_error,objeto_error);

        zfstzfw_admon_errores.Query$Nmerror(prcrErrRecord.Nmerror);

        if (not zfstzfw_admon_errores.SQL$$Found) then
                zfitzfw_admon_errores.Insert$(onmbErr,ovchErrMsg,prcrErrRecord);
        end if;

        onmbErr     := zfstzfw_admon_errores.Nmerror$$;

        if (zfstzfw_admon_errores.DsMensaje_Usuario$$ is null) then
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_bd$$||' '||objeto_error;
        else
            ovchErrMsg  := zfstzfw_admon_errores.DsMensaje_Usuario$$||' '||objeto_error;
        end if;

        return;
end Update$Auditoria;

--------------------------------------------------- SQL$$Found.fnc ----------------------------------------------------
function SQL$$Found
return boolean
is
begin
    return(sqlfound);
end SQL$$Found;
--------------------------------------------------- SQL$$Success.fnc --------------------------------------------------
function SQL$$Success
return boolean
is
begin
    return(sqlsuccess);
end SQL$$Success;
------------------------------------------------- Verifica$SiNotifica ---------------------------------------------------------
/****************************************************************************************

    MODIFICACION:
    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------                                             .
   6.0         20191212    Guillermo Prieto   Modificacion del paquete para incluir el procedimiento que para
                                              insertar las  notificaciones de los documentos de transporte por 
                                              compania de acuerdo al nuevo desarrollo
                                              de planillas de envio de la dian para precargar la informacion de 
                                              acuerdo a la historia de usuario 6 del documento
                                              F01-PS030223 Levantamiento de Requisitos Planilla de Envio
                                              CC17  DLLO06
*****************************************************************************************/
procedure Verifica$SiNotifica(
     inmbid                   in      number,
     oclbXML                  out     clob)
is 

   vchUltima_planillaEnvio    varchar2(50) := Null;
   vchXQuery                  varchar2(6000) :=Null;
   
   vchcdplaca                 tzfw_transitos_documentos.cdplaca%type := null;
   dtmfeingreso               tzfw_transitos_documentos.feingreso%type := null;
   vchcdcia_usuaria           tzfw_transitos_documentos.cdcia_usuaria%type := null;
   nmbnmtransito_documento    tzfw_transitos_documentos.nmtransito_documento%type := null;
   nmbid                      tzfw_transitos_documentos.id%type := null;
   vchcdusuario_aud           tzfw_transitos_documentos.cdusuario_aud%type := null;
   nmbtotal_reg               number :=0;
   nmbtotal_reg_autoriz       number :=0;
   nmbtotal_reg_notifeventos  number :=0;
   in_payloadSend             clob   := ' ';

   -- cursor para traer  la informacion de la placa, feingreso y cia para poder
   -- hacer los otros cursores con los conteos de todos los docuemntos de ingreso
   -- y si todos los documentos de ingreso estan autorizados para proceder a 
   -- ingresar la notificaion.
   CURSOR  cuTraerInfoTransitoDto(pid number)
   IS
   SELECT  td.cdplaca,td.feingreso feingreso, 
           td.cdcia_usuaria, td.nmtransito_documento, td.id, td.cdusuario_aud 
   FROM    tzfw_transitos_documentos  TD
   WHERE   id = pid;

   --cursor para recuperar el total de todos los docuemntos de ingreso de acuerdo a la
   --de la placa, feingreso y cia 
   CURSOR  cuTotalDtosTransitoDtos(pvchcdplaca varchar,pdtmfeingreso date, pvchcdcia_usuaria varchar)
   IS
   SELECT  count(0) total_reg
   FROM    tzfw_transitos_documentos  td
   WHERE   td.cdplaca=pvchcdplaca
   AND     td.feingreso=pdtmfeingreso 
   AND     td.cdcia_usuaria=pvchcdcia_usuaria;

   --cursor para recuperar el total de todos los docuemntos de ingreso que estan autorizados de acuerdo a la
   --de la placa, feingreso y cia 
   CURSOR  cuTotalDtosAutorTransitoDtos(pvchcdplaca varchar,pdtmfeingreso date, pvchcdcia_usuaria varchar)
   IS
   SELECT  count(0) total_reg
   FROM    tzfw_transitos_documentos  td
   WHERE   td.cdplaca=pvchcdplaca
   AND     td.feingreso=pdtmfeingreso 
   AND     td.cdcia_usuaria=pvchcdcia_usuaria
   AND     td.snautoriza='S';

--cursor para saber si el id esta en la tabla de notificaciones de eventos
   CURSOR  cuVerifIdenNotifEventos(pid number)
   IS
   SELECT  count(0) total_reg_notifeventos
   FROM    tzfw_transitos_documentos  td,tzfw_notificac_eventos ne
   WHERE   td.id=ne.idelemento 
   AND     ne.idelemento =pid;

begin 

    dbms_output.put_line (' antes del if inmbid' ||inmbid);

    Open cuTraerInfoTransitoDto(inmbid);
    Fetch  cuTraerInfoTransitoDto into vchcdplaca, dtmfeingreso, vchcdcia_usuaria, nmbnmtransito_documento, nmbid, vchcdusuario_aud;
    Close cuTraerInfoTransitoDto;

    if vchcdplaca is not null then
       Open cuTotalDtosTransitoDtos(vchcdplaca, dtmfeingreso, vchcdcia_usuaria);
       Fetch  cuTotalDtosTransitoDtos into nmbtotal_reg;
       Close cuTotalDtosTransitoDtos;

       Open cuTotalDtosAutorTransitoDtos(vchcdplaca, dtmfeingreso, vchcdcia_usuaria);
       Fetch  cuTotalDtosAutorTransitoDtos into nmbtotal_reg_autoriz;
       Close cuTotalDtosAutorTransitoDtos;
     
       if  (nmbtotal_reg > 0 and nmbtotal_reg_autoriz > 0) and 
           (nmbtotal_reg = nmbtotal_reg_autoriz) then
            Open cuVerifIdenNotifEventos(nmbid);
            Fetch  cuVerifIdenNotifEventos into nmbtotal_reg_notifeventos;
            Close cuVerifIdenNotifEventos;

            if nmbtotal_reg_notifeventos <= 0 then           
               --Graba notificacion
               prcrRecordNotific.CDELEMENTO := vchcdplaca;            
		       prcrRecordNotific.IDELEMENTO := nmbid;            
		       prcrRecordNotific.CDCIA_USUARIA := vchcdcia_usuaria;            
		       prcrRecordNotific.DSMENSAJE := 'La placa '|| vchcdplaca ||' ha sido autorizada.';            
		       prcrRecordNotific.CDIDENTIFICACION := vchcdusuario_aud;            

               zfstzfw_transitos_documentos.Grabar$Notificacion(prcrRecordNotific,oclbXML);
               if (oclbXML is not null) then
                  oclbXML := oclbXML;
               end if;       

              select JSON_OBJECT( 'tipointegracion' VALUE 'notificaciones_dian',
                        'codigozonafranca' VALUE (SELECT dsvalor FROM  tzfw_parametros t3 where t3.dsparametro='CODIGO_ZONA_FRANCA'),
                        'sysdate' VALUE SYSDATE,
                        'payload' VALUE to_clob(JSON_OBJECT(  'category' VALUE 'DIAN_messages',
                        'zonaFranca' VALUE (SELECT dsvalor FROM  tzfw_parametros t3 where t3.dsparametro='CODIGO_ZONA_FRANCA'), 
                        'cia' VALUE td.cdcia_usuaria,
                        'text' VALUE  'La placa '|| td.cdplaca ||' ha sido autorizada.',
                        'userAutenticado' VALUE  td.cdusuario_aud)))
               into   in_payloadSend
               from   dual,  tzfw_transitos_documentos  td
               where  td.id = nmbid
               and    rownum <=1;   
               
               ZF_PKG_SVC_SEND_RABBIT.PUBLISH_SERVER_RABBIT(in_payloadSend); 

            end if;       
       end if;       

    end if;
exception  
   when others then 
      oclbXML := ocblMensaje||'<ROW><CODE>'||sqlcode||'</CODE><DESCRIPTION>'||substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
                                             instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 )||'</DESCRIPTION></ROW>'||chr(10);
      ROLLBACK;
      raise;

end Verifica$SiNotifica;
------------------------------------------------ Grabar Notificacion ---------------------------------------------------------   
procedure Grabar$Notificacion(
    ircrRecord                      in      rtytzfw_notificac_eventos,
    oclbXML                         out     clob)
is
   --PRAGMA autonomous_transaction;
begin
    prcrRecordNotific := ircrRecord;    
  
	prcrRecordNotific.ID := SEQ_TZFW_NOTIFICAC_EVENTOS.NEXTVAL;
	prcrRecordNotific.DSEVENTO := 'PLANILLAS ENVIO - AUTORIZACION POR TRANSITO DOCUMENTOS  POR COMPANIA';
	prcrRecordNotific.FEEVENTO := sysdate;
	prcrRecordNotific.DSELEMENTO := 'PLACA';
	prcrRecordNotific.DSESTADO := 'P'; 	
	prcrRecordNotific.CDESTADO_EVENTO := 'A';
	prcrRecordNotific.FEESTADO_EVENTO := sysdate;		

    insert into tzfw_notificac_eventos values prcrRecordNotific;    
    sqlsuccess := sql%rowcount > 0;
    COMMIT;
exception 
   when others then
      oclbXML := ocblMensaje||'<ROW><CODE>'||sqlcode||'</CODE><DESCRIPTION>'||substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
                 instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 )||'</DESCRIPTION></ROW>'||chr(10);

end Grabar$Notificacion;
--=====================================================================================================================
-----------------------------------------------------------------------------------------------------------------------
function QueryTipoDesprecinte(         
         ivchCiaUsuaria                  in tzfw_transitos_documentos.cdcia_usuaria%type,
         ivchPlaca                       in tzfw_transitos_documentos.cdplaca%type,
         idtFeIngreso                    in varchar2,
         inmbTransito                    in tzfw_transitos_documentos.nmtransito_documento%type)
return number
is
    vchTipo     tzfw_transitos_documentos.cdtipo_documento%type;
    vchValor    tzfw_parametros.dsvalor%type;
    vchTransito tzfw_transitos_documentos.nmtransito%type;
    nmbTotal    number;
begin
    -- consulta el tipo de documento del transito
dbms_output.put_line('paso1 '||ivchCiaUsuaria||ivchPlaca||idtFEINGRESO||inmbTransito);    
    select cdtipo_documento, nmtransito
    into vchTipo, vchTransito
    from tzfw_transitos_documentos
    where cdcia_usuaria=ivchCiaUsuaria
    and cdplaca= ivchPlaca
    and feingreso=to_date(idtFEINGRESO ,'yyyy-mm-dd hh24:mi:ss')
    and nmtransito_documento=inmbTransito;
dbms_output.put_line('paso1 '||inmbTransito);    
    -- se valida si es un transito
    select INSTR(dsvalor,vchTipo)
    into vchValor
    from tzfw_parametros 
    where dsparametro='TRANSITO';
dbms_output.put_line('paso1 '||vchValor);
    if vchValor > 0 then -- Si es transito
        -- se valida que no tenga envio 
dbms_output.put_line('entra2 '||ivchCiaUsuaria||' '||inmbTransito);        
        select count(1)
        into nmbTotal
        from tzfw_audit_planilla
        where cdcia_usuaria=ivchCiaUsuaria
        and cdplaca= ivchPlaca
        and feingreso=to_date(idtFEINGRESO,'yyyy-mm-dd hh24:mi:ss')
        and (cdvalor_actual ='T' or cdvalor_anterior='T')
        and nmtransito_documento=inmbTransito;
        
        if nmbTotal > 0 then return nmbTotal; end if;
       -- se valida si la placa y compaï¿½ia ya tienen tipo desprecinte
        select count(1)
        into nmbTotal
        from tzfw_camiones
        where cdplaca= ivchPlaca
        and feingreso=to_date(idtFEINGRESO ,'yyyy-mm-dd hh24:mi:ss')        
        and cdtipodesprecinte in('A','F');                
        return nmbTotal;-- si es mayor a 1 ya tiene tipo desprecinte
        -- si es 0 
    else
       return 1; -- no se pregunta
    end if;

EXCEPTION 
    WHEN NO_DATA_FOUND then -- KSB 23/12/2021 Se ajusta para retornar valor de excepcion y poder controlar el error
        return -1;
end QueryTipoDesprecinte;
-----------------------------------------------------------------------------------------------------------------------
function QueryModTipoDesprecinte(         
         ivchCiaUsuaria                  in tzfw_transitos_documentos.cdcia_usuaria%type,
         ivchPlaca                       in tzfw_transitos_documentos.cdplaca%type,
         idtFeIngreso                    in varchar2,
         inmbTransito                    in tzfw_transitos_documentos.nmtransito_documento%type)
return number
is
    nmbTotal    number;
    vchTipo     tzfw_transitos_documentos.cdtipo_documento%type;
    vchValor    tzfw_parametros.dsvalor%type;
begin
dbms_output.put_line('entra');
    -- consulta el tipo de documento del transito
    select cdtipo_documento
    into vchTipo
    from tzfw_transitos_documentos
    where cdcia_usuaria=ivchCiaUsuaria
    and cdplaca= ivchPlaca
    and feingreso=to_date(idtFEINGRESO ,'yyyy-mm-dd hh24:mi:ss')
    and nmtransito_documento=inmbTransito;
dbms_output.put_line('entra1');
    -- se valida si es un transito
    select INSTR(dsvalor,vchTipo)
    into vchValor
    from tzfw_parametros 
    where dsparametro='TRANSITO';
dbms_output.put_line('entra2');
    if vchValor > 0 then -- Si es transito
       -- se valida que no se haya enviado
        select count(1)
        into nmbTotal
        from tzfw_audit_planilla
        where cdplaca= ivchPlaca
        and feingreso=to_date(idtFEINGRESO,'yyyy-mm-dd hh24:mi:ss')
        and (cdvalor_actual ='T' or cdvalor_anterior='T');
        --and nmtransito_documento=inmbTransito;
dbms_output.put_line(nmbTotal||' '||idtFEINGRESO);
        if nmbTotal > 0 then return nmbTotal; end if;
                
        return nmbTotal;-- si es mayor a 1 ya fue enviado, no se puede modificar
        -- si es 0 
    else
       return 0; -- no se puede editar
    end if;

end QueryModTipoDesprecinte;
------------------------------------------------------------------------------------------------------------------------
procedure UpdateTipoDesprecinte(
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,
    ircrRecord                     in       rtytzfw_transitos_documentos,
    ivchTipo                       in       tzfw_camiones.CDTIPODESPRECINTE%type,
    ivchComentario                 in       tzfw_camiones.DSCOMENTARIODESPRE%type)
is
    vchPlaca        tzfw_transitos_documentos.cdplaca%type;
    dtFeingreso     tzfw_transitos_documentos.feingreso%type;
begin    
    select cdplaca,feingreso
    into vchPlaca,dtFeingreso
    from tzfw_transitos_documentos
    where id= ircrRecord.id;
    
    UPDATE TZFW_camiones
       SET  cdtipodesprecinte = ivchTipo,
            dscomentariodespre = ivchComentario
    WHERE   cdplaca= vchPlaca
    and     feingreso =dtFeingreso;
    sqlsuccess := sql%rowcount > 0;

    return;
exception
  when others then
    onmbError := sqlcode;
    ovchMessaje := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
        instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

end UpdateTipoDesprecinte;
------------------------------------------------------------------------------------------------------------------------
procedure UpdateSolDesprecinte(
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,    
    ivchPlaca                      in       tzfw_camiones.cdplaca%type,
    idtFecha                       in       varchar2,
    ivchsol                        in       tzfw_camiones.CDNROSOL%type)
is
begin
    
    UPDATE TZFW_camiones
       SET  cdnrosol = nvl(cdnrosol,'')||ivchsol||'-'
    WHERE   cdplaca= ivchPlaca
    and     feingreso = to_date(idtFecha,'yyyy-mm-dd hh24:mi:ss');
    sqlsuccess := sql%rowcount > 0;

    return;
exception
  when others then
    onmbError := sqlcode;
    ovchMessaje := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
        instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

end UpdateSolDesprecinte;
------------------------------------------------------------------------------------------------------------------------
procedure EnvioTipoDesprecinte(
    ivchPlaca                      in       tzfw_transitos_documentos.cdplaca%type,
    ivchCia                        in       tzfw_transitos_documentos.cdcia_usuaria%type,
    idtFecha                       in       tzfw_transitos_documentos.feingreso%type,
    ivchUsuario                    in       tzfw_transitos_documentos.cdusuario_aud%type,
    ivchcompania                   in       tzfw_transitos_documentos.cdcia_usuaria%type,
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,
    onmbTipo                       out      number,
    ovchCorreo                     out      varchar,
    ovchTipoDespre                 out      varchar
    )
is
    nmbTotal    number;
    vchTipo     tzfw_camiones.cdtipodesprecinte%type;
    vchNroSol   tzfw_camiones.cdnrosol%type;
    vchCampo    varchar2(5000);
begin
    -- consulta si la placa tiene transitos, y se ha marcado como automatico o fisico el tipo de desprecinte
    with tmp as(
    select INSTR(dsvalor,cdtipo_documento) val, T.cdtipo_documento,nmtransito,cdtipodesprecinte, cdnrosol
    from tzfw_transitos_documentos t,tzfw_parametros t1, tzfw_camiones t2
    where t.cdplaca=ivchPlaca
    and t.feingreso = idtFecha
    and t.cdcia_usuaria=ivchCia
    and t.cdplaca = t2.cdplaca
    and t.feingreso = t2.feingreso
    and dsparametro='TRANSITO'    
    and cdtipodesprecinte in('A','F') )
    select cdtipodesprecinte,cdnrosol
    into vchTipo,vchNroSol
    from tmp
    where val>0
    and rownum=1;
    
    with tmp as(
    select INSTR(dsvalor,cdtipo_documento) val, T.cdtipo_documento,nmtransito,'A' cdtipodesprecinte
    from tzfw_transitos_documentos t,tzfw_parametros t1
    where cdplaca=ivchPlaca
    and feingreso = idtFecha
    and cdcia_usuaria=ivchCia
    and dsparametro='TRANSITO')
    select distinct LISTAGG(nmtransito, ',') WITHIN GROUP (ORDER BY nmtransito) over (partition by cdtipodesprecinte) campo
    into vchCampo
    from tmp t
    where val>0;

    onmbTipo :=0;
    ovchTipoDespre := vchTipo;
    if vchTipo ='A' then
        ovchMessaje:='Puede desprecintar los siguientes transitos '||vchCampo;        
    else
        ovchMessaje:='IMPORTANTE!!!'||chr(10) ||' Los siguientes transitos requieren inspección del operador para el desprecinte '||vchCampo;               
        zfstzfw_parametros.Query$DsParametro('GENERAR_SOLICITUD_DESPRECINTE');
        if zfstzfw_parametros.SQL$$Found = true then
            if zfstzfw_parametros.DsValor$$ ='S' then
                -- se valida si la placa ya tiene nro de solicitud generada
                if vchNroSol is null then
                    -- se debe generar la solicitud
                    onmbTipo :=1;                
                else
                    ovchMessaje := ovchMessaje||chr(10) ||'Sr usuario tiene una solicitud de inspección previa, si requiere una nueva por favor radicarla manualmente';
                end if;
            end if;
        end if;
    end if;
 dbms_output.put_line(ivchCompania);   
 dbms_output.put_line(ivchUsuario);   
    begin
        select correo
        into ovchCorreo
        from TZFW_USUARIO_CORREO t
        where cdidentificacion = ivchUsuario
        and cdcia_usuaria=ivchCompania;
                
        
    exception 
        when no_data_found then
           ovchCorreo:='-1';
           onmbTipo :='0';
    end;
    return;
exception
  when no_data_found then 
        null;
  when others then
    onmbError := sqlcode;
    ovchMessaje := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
        instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

end EnvioTipoDesprecinte;
------------------------------------------------------------------------------------------------------------------------
procedure CrearSolicitud(
    ivchPlaca                      in       tzfw_transitos_documentos.cdplaca%type,
    ivchCia                        in       tzfw_transitos_documentos.cdcia_usuaria%type,
    idtFecha                       in       tzfw_transitos_documentos.feingreso%type,    
    ivchUsuario                    in       tzfw_transitos_documentos.cdusuario_aud%type,
    ivchCompania                   in       tzfw_transitos_documentos.cdcia_usuaria%type,
    oclbRta                        out      clob,
    onmbError                      out      number,
    ovchMessaje                    out      varchar2
    )
is
    nmbTotal    number;
    vchComentario     tzfw_camiones.dscomentariodespre%type;
    --vchNroSol   tzfw_transitos_documentos.cdnrosol%type;
    vchZona     tzfw_parametros.dsvalor%type;    
    vchSubmotivo     tzfw_parametros.dsvalor%type;
    vchAsignado tzfw_parametros.dsvalor%type;
    vchMotivo   tzfw_parametros.dsvalor%type;    
    vchXQuery   varchar2(5000);
    vchTransito varchar2(1000);
    vchCorreo   tzfw_usuario_correo.correo%type;
begin
    zfstzfw_parametros.Query$DsParametro('SOL_ASIGNADO_A');
    if zfstzfw_parametros.SQL$$Found = false then
        onmbError := -1;
        ovchMessaje := 'SOL_ASIGNADO_A,';
    else
        vchAsignado := zfstzfw_parametros.DsValor$$;
    end if;
    
    zfstzfw_parametros.Query$DsParametro('SOL_MOTIVO');
    if zfstzfw_parametros.SQL$$Found = false then
        onmbError := -1;
        ovchMessaje := ovchMessaje||'SOL_MOTIVO,';
    else
        vchMotivo := zfstzfw_parametros.DsValor$$;
    end if;
    
    zfstzfw_parametros.Query$DsParametro('SOL_SUBMOTIVO');
    if zfstzfw_parametros.SQL$$Found = false then
        onmbError := -1;
        ovchMessaje := ovchMessaje||'SOL_SUBMOTIVO,';
    else
        vchSubmotivo :=  zfstzfw_parametros.DsValor$$;
    end if;
    
    if onmbError = -1 then
        ovchMessaje:= 'No existen los parametros '||ovchMessaje||chr(10)||'Señor usuario radique la solicitud de desprecinte para este transito.';
        return;
    end if;
    
    zfstzfw_parametros.Query$DsParametro('CODIGO_ZONA_FRANCA');
    if zfstzfw_parametros.SQL$$Found = true then
      vchZona := zfstzfw_parametros.DsValor$$;
   end if;
   
   select LISTAGG(nmtransito,', ') WITHIN GROUP (ORDER BY nmtransito)
   into vchTransito
   from tzfw_transitos_documentos t
   where cdplaca=ivchPlaca
   and cdcia_usuaria=ivchCia;
    
   begin
      select dscomentariodespre
      into vchComentario
      from tzfw_camiones t
      where cdplaca=ivchPlaca
      and feingreso=idtFecha
      and cdtipodesprecinte ='F'
      and dscomentariodespre is not null;
   exception
      when no_data_found then null;
   end;
   
    begin
      select correo
      into vchCorreo
      from tzfw_usuario_correo t
      where cdidentificacion=ivchUsuario
      and cdcia_usuaria=ivchCompania;
   exception
      when no_data_found then null;
   end;
    vchXQuery := 'select '||vchZona||' cod_zona_franca,'
              ||''''||ivchCia||''' cia_usuaria, '
              ||'''Solicitud'' tipo, '
              ||''''||vchAsignado||''' asignado_a, '
              ||''''||vchMotivo||''' motivo, '
              ||''''||vchSubmotivo||''' submotivo, '
              ||' max(dsnombre) dsnombre, '
              ||' nvl('''||vchCorreo||''','' '') correo, '
              ||' t.cdidentificacion, '
              ||'sum(nmbultos_rel) bultos_rel, '
              ||'sum(nmpeso_rel) peso_rel, '
              ||' max(nmformulario_zf)nmformulario_zf, '
              ||''''||ivchPlaca||''' cdplaca, '
              ||''''||vchTransito||''' duta, '
              ||''''||nvl(vchComentario,' ')||''' comentario '
              || 'from   dual, tzfw_usuarios t, tzfw_documentos_x_cia t2 , tzfw_transitos_documentos t3 '
              ||' where t.cdidentificacion='''||ivchUsuario||''''             
              ||' and t2.cdplaca = '''||ivchPlaca||''''    
              ||' and t.cdcia_usuaria = '''||ivchCompania||'''' 
              ||' and t2.cdcia_usuaria = '''||ivchCia||'''' 
              ||' and t2.cdplaca = t3.cdplaca '
              ||' and t2.feingreso = t3.feingreso '
              ||' and t2.cdcia_usuaria = t3.cdcia_usuaria '
              ||' and t2.nmtransito_documento = t3.nmtransito_documento '
              ||' group by t.cdidentificacion ';
 dbms_output.put_line(vchXQuery);
    oclbRta := dbms_xmlgen.getXML(vchXQuery);
    
    return;
exception    
when others then
    onmbError := sqlcode;
    ovchMessaje := substr(sqlerrm,instr(sqlerrm,':') + 1, length(substr(sqlerrm,1,
        instr(sqlerrm,'(')-2)) - instr(sqlerrm,':') + 1 );

end CrearSolicitud;
------------------------------------------------------------------------------------------------------------------------
procedure UpdateTipoDespre(
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,
    ivchPlaca                      in       tzfw_camiones.cdplaca%type,
    idtFeIngreso                   in       tzfw_camiones.feingreso%type,
    ivchTipo                       in       tzfw_camiones.CDTIPODESPRECINTE%type,
    ivchComentario                 in       tzfw_camiones.DSCOMENTARIODESPRE%type)
is

begin

    UPDATE TZFW_camiones
       SET  cdtipodesprecinte = ivchTipo,
            dscomentariodespre = ivchComentario
    WHERE   cdplaca = ivchPlaca
    and feingreso = idtFeIngreso;    
        
    return;
exception
  when no_data_found then
     onmbError := 0;
  when others then
    onmbError := -1;
    ovchMessaje := sqlerrm;

end UpdateTipoDespre;
------------------------------------------------------XVerificarTransito.prc-----------------------------------------------------------
procedure xPlaca(
        ivchCia                      in      tzfw_transitos_documentos.cdcia_usuaria%type,
        ivchTransito                 in      tzfw_transitos_documentos.nmtransito%type,
        oclbXML                         out     clob)
is    
    vchXQuery                       varchar2(2048);
begin    
    vchXQuery := 'select '
              || 't.cdplaca, '
              || 'to_char(t.feingreso,''yyyy-mm-dd hh24:mi:ss'') feingreso , '
              || 't.cdcia_usuaria,NMTRANSITO_DOCUMENTO  '              
              || 'from   TZFW_TRANSITOS_DOCUMENTOS t '              
              || 'where  t.cdcia_usuaria = '''||ivchCia||''''
              || ' and t.nmtransito = '''||ivchTransito||'''';
dbms_output.put_line(vchXQuery);              
    oclbXML := dbms_xmlgen.getXML(vchXQuery);
    return;
end xPlaca;
--=====================================================================================================================
begin
 null;

end zfstzfw_transitos_documentos;
MODULE pycpl
   !!======================================================================
   !!                       ***  MODULE  pycpl  ***
   !! Python coupling module : manage coupling with external Python codes deployed with Eophis
   !!======================================================================
   !! History :  4.2.1  ! 2025-11  (A. Barge)  Original code
   !!----------------------------------------------------------------------

   !!----------------------------------------------------------------------
   !!   init_python_coupling     : Initialize coupling with Python
   !!   send_to_python           : send fields to external Python model
   !!   receive_from_python      : receive fields from external Python model
   !!   finalize_python_coupling : Free memory
   !!----------------------------------------------------------------------
   USE oce             ! ocean fields
   USE dom_oce         ! ocean domain fields
   USE pyfld           ! working fields for python models
   USE cpl_oasis3      ! OASIS3 coupling
   USE eophis_def      ! Eophis inputs
   USE timing
   USE iom
   USE in_out_manager
   USE lib_mpp

   IMPLICIT NONE
   PUBLIC

   INTEGER, SAVE, PRIVATE ::   jpexch        ! Maximum number of exchanges

   TYPE( DYNARR ), PRIVATE, SAVE, ALLOCATABLE ::  fldsnd(:), fldrcv(:)  ! sent/received fields

   INTERFACE send_to_python
      MODULE PROCEDURE send_to_python_3d, send_to_python_2d
   END INTERFACE send_to_python

   INTERFACE receive_from_python
      MODULE PROCEDURE receive_from_python_3d, receive_from_python_2d
   END INTERFACE receive_from_python


CONTAINS

   SUBROUTINE init_python_coupling()
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE init_python_coupling  ***
      !!
      !! ** Purpose :   Initialisation of the coupling that relies on eophis
      !!
      !! ** Method  :   * Read eophis namelist
      !!                * Define exchanges
      !!                * Configure OASIS
      !!----------------------------------------------------------------------
      ! I/O
      ! local variables
      INTEGER ::   ios, jsnd = 1, jrcv = 1  ! Local Integer
      TYPE(eophis_var), POINTER :: curr_var
      !!----------------------------------------------------------------------
      !
      ! ===============
      !    Initialize
      ! ===============
      !
      IF( .NOT. lk_oasis )   CALL ctl_stop( 'init_python_coupling : key_oasis3 disabled' )
      !
      IF( lwp ) THEN                        ! control print
         WRITE(numout,*)
         WRITE(numout,*)'init_python_coupling : Setting Python models'
         WRITE(numout,*)'~~~~~~~~~~~~~~~~~~~~'
      END IF
      !
      IF( lwp ) WRITE(numout,*) '      Reading Eophis namelist'
      !
      CALL build_eophis_list(mpi_comm_oce)
      jpexch = count_eophis_var()
      !
      ! ==================================== !
      !     Define exchanges from Eophis     !
      ! ==================================== !
      !
      IF( lwp ) WRITE(numout,*) '      Configure OASIS for inferences module'
      !
      ! default definitions of ssnd snd srcv
      srcv(ntypinf,:)%laction = .FALSE.  ;  srcv(ntypinf,:)%clgrid = 'T'  ;  srcv(ntypinf,:)%nsgn = 1.
      srcv(ntypinf,:)%nct = 1  ;  srcv(ntypinf,:)%nlvl = 1
      !
      ssnd(ntypinf,:)%laction = .FALSE.  ;  ssnd(ntypinf,:)%clgrid = 'T'  ;  ssnd(ntypinf,:)%nsgn = 1.
      ssnd(ntypinf,:)%nct = 1  ;  ssnd(ntypinf,:)%nlvl = 1
      !
      !
      CALL first_eophis_var(curr_var)
      DO WHILE (associated(curr_var))
         IF(.NOT.curr_var%in) THEN
            ssnd(ntypinf,jsnd)%clname = curr_var%alias
            ssnd(ntypinf,jsnd)%laction = .TRUE.
            ssnd(ntypinf,jsnd)%nlvl = curr_var%nlvl
            curr_var%idx = jsnd
            jsnd = jsnd + 1
         ELSE
            srcv(ntypinf,jrcv)%clname = curr_var%alias
            srcv(ntypinf,jrcv)%laction = .TRUE.
            srcv(ntypinf,jrcv)%nlvl = curr_var%nlvl
            curr_var%idx = jrcv
            jrcv = jrcv + 1
         ENDIF
         CALL eophis_next_var(curr_var)
      END DO
      !
      ! ===================== !
      !    Configure OASIS    !
      ! ===================== !
      CALL cpl_var(jpexch, jpexch, 1, ntypinf)
      !
      IF( pycpl_alloc() /= 0 )     CALL ctl_stop( 'STOP', 'pycpl_alloc : unable to allocate arrays' )
      IF( pyfld_alloc() /= 0 )     CALL ctl_stop( 'STOP', 'pyfld_alloc : unable to allocate arrays' )
      !
   END SUBROUTINE init_python_coupling


   SUBROUTINE send_to_python_3d(varname,to_send,kt)
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE send_to_python ***
      !!
      !! ** Purpose :   Proceed OASIS sending from Eophis definition
      !!
      !! ** Arguments : CHAR varname : name of the field to send
      !!                REAL(:,:,:) to_send  : Array to send
      !!                INT kt : ocean time step
      !!----------------------------------------------------------------------
      !!----------------------------------------------------------------------
      ! I/O
      INTEGER, INTENT(in)           ::  kt             ! ocean time step
      CHARACTER(len=*), INTENT(in)  :: varname
      REAL(wp), DIMENSION(jpi,jpj,jpk), INTENT(in) ::  to_send
      ! local variables
      INTEGER :: jn, isec, info
      TYPE(eophis_var), POINTER :: curr_var
      !!----------------------------------------------------------------------
      !
      ! Date of exchange
      isec = ( kt - nit000 ) * NINT( rn_Dt )
      info = OASIS_idle
      !
      ! Get Eophis variable
      CALL find_eophis_var(varname,curr_var)
      !
      ! OASIS layer
      IF (curr_var%in) THEN
         CALL ctl_stop( 'send_to_python : function called for an incoming variable' )
      ELSE
         jn = curr_var%idx
         fldsnd(jn)%z3(:,:,1:ssnd(ntypinf,jn)%nlvl) = to_send(:,:,1:ssnd(ntypinf,jn)%nlvl)
         CALL cpl_snd(jn, isec, ntypinf, fldsnd(jn)%z3, info)
      END IF
      !
   END SUBROUTINE send_to_python_3d


   SUBROUTINE send_to_python_2d(varname,to_send,kt)
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE send_to_python ***
      !!
      !! ** Purpose :   Proceed OASIS sending from Eophis definition
      !!
      !! ** Arguments : CHAR varname : name of the field to send
      !!                REAL(:,:) to_send  : Array to send
      !!                INT kt : ocean time step
      !!----------------------------------------------------------------------
      !!----------------------------------------------------------------------
      ! I/O
      INTEGER, INTENT(in)           ::  kt             ! ocean time step
      CHARACTER(len=*), INTENT(in)  :: varname
      REAL(wp), DIMENSION(jpi,jpj), INTENT(in) ::  to_send
      ! local variables
      INTEGER :: jn, isec, info
      TYPE(eophis_var), POINTER :: curr_var
      !!----------------------------------------------------------------------
      !
      ! Date of exchange
      isec = ( kt - nit000 ) * NINT( rn_Dt )
      info = OASIS_idle
      !
      ! Get Eophis variable
      CALL find_eophis_var(varname,curr_var)
      !
      ! OASIS layer
      IF (curr_var%in) THEN
         CALL ctl_stop( 'send_to_python : function called for an incoming variable' )
      ELSE
         jn = curr_var%idx
         fldsnd(jn)%z3(:,:,ssnd(ntypinf,jn)%nlvl) = to_send(:,:)
         CALL cpl_snd(jn, isec, ntypinf, fldsnd(jn)%z3, info)
      END IF
      !
   END SUBROUTINE send_to_python_2d


   SUBROUTINE receive_from_python_3d(varname,to_rcv,kt)
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE receive_from_python  ***
      !!
      !! ** Purpose :   Proceed OASIS receiving from Eophis definition
      !!
      !! ** Arguments : CHAR varname : name of the field to receive
      !!                REAL(:,:,:) to_rcv : Array in which store received field
      !!                INT kt : ocean time step
      !!----------------------------------------------------------------------
      !!----------------------------------------------------------------------
      ! I/O
      INTEGER, INTENT(in)           ::  kt
      CHARACTER(len=*), INTENT(in)  :: varname
      REAL(wp), DIMENSION(jpi,jpj,jpk), INTENT(out) ::  to_rcv
      ! local variables
      INTEGER :: jn, info, isec
      TYPE(eophis_var), POINTER :: curr_var
      !!----------------------------------------------------------------------
      !
      ! Date of exchange
      isec = ( kt - nit000 ) * NINT( rn_Dt )
      info = OASIS_idle
      !
      ! Get Eophis variable
      CALL find_eophis_var(varname,curr_var)
      !
      ! OASIS layer
      IF (.NOT. curr_var%in) THEN
         CALL ctl_stop( 'receive_from_python : function called for an outcoming variable')
      ELSE
         jn = curr_var%idx
         CALL cpl_rcv(jn, isec, ntypinf, fldrcv(jn)%z3, info)
         to_rcv(:,:,1:srcv(ntypinf,jn)%nlvl) = fldrcv(jn)%z3(:,:,1:srcv(ntypinf,jn)%nlvl)
      END IF
      !
   END SUBROUTINE receive_from_python_3d


   SUBROUTINE receive_from_python_2d(varname,to_rcv,kt)
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE receive_from_python  ***
      !!
      !! ** Purpose :   Proceed OASIS receiving from Eophis definition
      !!
      !! ** Arguments : CHAR varname : name of the field to receive
      !!                REAL(:,:) to_rcv : Array in which store received field
      !!                INT kt : ocean time step
      !!----------------------------------------------------------------------
      !!----------------------------------------------------------------------
      ! I/O
      INTEGER, INTENT(in)           ::  kt
      CHARACTER(len=*), INTENT(in)  :: varname
      REAL(wp), DIMENSION(jpi,jpj), INTENT(out) ::  to_rcv
      ! local variables
      INTEGER :: jn, info, isec
      TYPE(eophis_var), POINTER :: curr_var
      !!----------------------------------------------------------------------
      !
      ! Date of exchange
      isec = ( kt - nit000 ) * NINT( rn_Dt )
      info = OASIS_idle
      !
      ! Get Eophis variable
      CALL find_eophis_var(varname,curr_var)
      !
      ! OASIS layer
      IF (.NOT. curr_var%in) THEN
         CALL ctl_stop( 'receive_from_python : function called for an outcoming variable')
      ELSE
         jn = curr_var%idx
         CALL cpl_rcv(jn, isec, ntypinf, fldrcv(jn)%z3, info)
         to_rcv(:,:) = fldrcv(jn)%z3(:,:,srcv(ntypinf,jn)%nlvl)
      END IF
      !
   END SUBROUTINE receive_from_python_2d


   SUBROUTINE finalize_python_coupling
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE finalize_python_coupling  ***
      !!
      !! ** Purpose :   Free memory used for Python coupling
      !!
      !! ** Method  :   * Deallocate arrays
      !!----------------------------------------------------------------------
      !
      IF( pycpl_dealloc() /= 0 )     CALL ctl_stop( 'STOP', 'inf_dealloc : unable to free memory' )
      IF( pyfld_dealloc() /= 0 )  CALL ctl_stop( 'STOP', 'inffld_dealloc : unable to free memory' )
      CALL purge_eophis()
      !
   END SUBROUTINE finalize_python_coupling


   INTEGER FUNCTION pycpl_alloc()
      !!----------------------------------------------------------------------
      !!             ***  FUNCTION pycpl_alloc  ***
      !!----------------------------------------------------------------------
      INTEGER :: ierr
      INTEGER :: jn
      !!----------------------------------------------------------------------
      ierr = 0
      !
      ALLOCATE(fldsnd(jpexch),fldrcv(jpexch), STAT=ierr)
      !
      DO jn = 1, jpexch
         IF( srcv(ntypinf,jn)%laction ) ALLOCATE( fldrcv(jn)%z3(jpi,jpj,srcv(ntypinf,jn)%nlvl), STAT=ierr )
         IF( ssnd(ntypinf,jn)%laction ) ALLOCATE( fldsnd(jn)%z3(jpi,jpj,ssnd(ntypinf,jn)%nlvl), STAT=ierr )
         pycpl_alloc = MAX(ierr,0)
      END DO
      !
   END FUNCTION pycpl_alloc


   INTEGER FUNCTION pycpl_dealloc()
      !!----------------------------------------------------------------------
      !!             ***  FUNCTION pycpl_dealloc  ***
      !!----------------------------------------------------------------------
      INTEGER :: ierr
      INTEGER :: jn
      !!----------------------------------------------------------------------
      ierr = 0
      !
      DO jn = 1, jpexch
         IF( srcv(ntypinf,jn)%laction ) DEALLOCATE( fldrcv(jn)%z3, STAT=ierr )
         IF( ssnd(ntypinf,jn)%laction ) DEALLOCATE( fldsnd(jn)%z3, STAT=ierr )
         pycpl_dealloc = MAX(ierr,0)
      END DO
      !
      DEALLOCATE(fldrcv,fldsnd)
      !
   END FUNCTION pycpl_dealloc

END MODULE pycpl

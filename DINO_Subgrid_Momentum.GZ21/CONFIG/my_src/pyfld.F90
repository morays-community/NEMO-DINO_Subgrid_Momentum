MODULE pyfld
   !!======================================================================
   !!                       ***  MODULE pyfld  ***
   !! Python module :   variables defined in core memory
   !!======================================================================
   !! History :  4.2  ! 2025-11  (A. Barge)  Original code
   !!----------------------------------------------------------------------

   !!----------------------------------------------------------------------
   !!   pyfld_alloc : allocation of fields arrays for Python coupling module (pycpl)
   !!----------------------------------------------------------------------
   !!=====================================================
   USE par_oce        ! ocean parameters
   USE lib_mpp        ! MPP library

   IMPLICIT NONE
   PRIVATE

   PUBLIC   pyfld_alloc   ! routine called in pycpl.F90
   PUBLIC   pyfld_dealloc ! routine called in pycpl.F90

   !!----------------------------------------------------------------------
   !!                    2D Python coupling Module fields
   !!----------------------------------------------------------------------
   !REAL(wp), PUBLIC, ALLOCATABLE, SAVE, DIMENSION(:,:)  :: tmp_fld_2D    !: dummy field to store 2D fields

   !!----------------------------------------------------------------------
   !!                    3D Python coupling Module fields
   !!----------------------------------------------------------------------
   REAL(wp), PUBLIC, ALLOCATABLE, SAVE, DIMENSION(:,:,:)  :: ext_uf, ext_vf  !: dummy field to store 3D fields

CONTAINS

   INTEGER FUNCTION pyfld_alloc()
      !!---------------------------------------------------------------------
      !!                  ***  FUNCTION pyfld_alloc  ***
      !!---------------------------------------------------------------------
      INTEGER :: ierr
      !!---------------------------------------------------------------------
      ierr = 0
      !
      ALLOCATE( ext_uf(jpi,jpj,jpk) , ext_vf(jpi,jpj,jpk)  , STAT=ierr )
      pyfld_alloc = ierr
      !
   END FUNCTION

   
   INTEGER FUNCTION pyfld_dealloc()
      !!---------------------------------------------------------------------
      !!                  ***  FUNCTION pyfld_dealloc  ***
      !!---------------------------------------------------------------------
      INTEGER :: ierr
      !!---------------------------------------------------------------------
      ierr = 0
      !
      DEALLOCATE( ext_uf , ext_vf  , STAT=ierr )
      pyfld_dealloc = ierr
      !
   END FUNCTION

END MODULE pyfld

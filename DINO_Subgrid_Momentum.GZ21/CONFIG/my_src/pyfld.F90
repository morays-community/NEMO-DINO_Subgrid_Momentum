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
   USE oce            ! ocean fields
   USE dom_oce        ! ocean metrics fields
   USE par_oce        ! ocean parameters
   USE lib_mpp        ! MPP library
   USE pycpl          ! Python coupling module
   USE iom

   IMPLICIT NONE
   PUBLIC

   !!----------------------------------------------------------------------
   !!                    2D Python coupling Module fields
   !!----------------------------------------------------------------------
   !REAL(wp), PUBLIC, ALLOCATABLE, SAVE, DIMENSION(:,:)  :: tmp_fld_2D    !: dummy field to store 2D fields

   !!----------------------------------------------------------------------
   !!                    3D Python coupling Module fields
   !!----------------------------------------------------------------------
   REAL(wp), PUBLIC, ALLOCATABLE, SAVE, DIMENSION(:,:,:)  :: ext_uf, ext_vf  !: dummy field to store 3D fields

CONTAINS

   SUBROUTINE init_python_fields()
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE init_python_fields  ***
      !!
      !! ** Purpose :   Initialisation of the Python module
      !!
      !! ** Method  :   * Allocate arrays for Python fields
      !!                * Configure Python coupling
      !!----------------------------------------------------------------------
      !
      ! Allocate fields
      ALLOCATE( ext_uf(jpi,jpj,jpk) , ext_vf(jpi,jpj,jpk) )
      !
      ! configure coupling
      CALL init_python_coupling()
      !
   END SUBROUTINE init_python_fields


   SUBROUTINE finalize_python_fields()
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE finalize_python_fields  ***
      !!
      !! ** Purpose :   Free memory used by Python module
      !!
      !! ** Method  :   * deallocate arrays for Python fields
      !!                * deallocate Python coupling
      !!----------------------------------------------------------------------
      !
      ! Free memory
      DEALLOCATE( ext_uf, ext_vf )
      !
      ! terminate coupling environment
      CALL finalize_python_coupling()
      !
   END SUBROUTINE finalize_python_fields


   SUBROUTINE inputs_gz21( kt, Nbb )
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE inputs_gz21  ***
      !!
      !! ** Purpose :   send inputs fileds for gz21 model
      !!
      !! ** Method  :   *
      !!                *
      !!----------------------------------------------------------------------
      INTEGER, INTENT(in) ::   kt            ! ocean time step
      INTEGER, INTENT(in) ::   Nbb           ! time index
      !!----------------------------------------------------------------------
      !
      ! send velocities and masks
      CALL send_to_python( 'u', uu(:,:,:,Nbb), kt )    ! Send fields to Python models
      CALL send_to_python( 'v', vv(:,:,:,Nbb), kt )    ! Send fields to Python models
      CALL send_to_python( 'mask_u', umask, kt )    ! Send fields to Python models
      CALL send_to_python( 'mask_v', vmask, kt )    ! Send fields to Python models
      !
   END SUBROUTINE inputs_gz21

   SUBROUTINE update_from_gz21( kt, Nrhs )
      !!----------------------------------------------------------------------
      !!             ***  ROUTINE update_from_gz21  ***
      !!
      !! ** Purpose :   update the ocean data with the coupled GZ21 models
      !!
      !! ** Method  :   *
      !!                *
      !!----------------------------------------------------------------------
      INTEGER, INTENT(in) ::   kt            ! ocean time step
      INTEGER, INTENT(in) ::   Nrhs          ! time index
      !!----------------------------------------------------------------------
      !
      ! Proceed receptions
      CALL receive_from_python( 'u_f', ext_uf, kt )
      CALL receive_from_python( 'v_f', ext_vf, kt )
      !
      ! update ocean
      uu(:,:,:,Nrhs) = uu(:,:,:,Nrhs) + ext_uf(:,:,:)
      vv(:,:,:,Nrhs) = vv(:,:,:,Nrhs) + ext_vf(:,:,:)
      !
      ! Outputs results
      CALL iom_put( 'ext_uf', ext_uf(:,:,1) )
      CALL iom_put( 'ext_vf', ext_vf(:,:,1) )
     !
   END SUBROUTINE update_from_gz21

END MODULE pyfld

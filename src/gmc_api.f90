!================================================================================!
! This file is part of crest.
!
! GMC fork capability and build-provenance API.
!================================================================================!
module gmc_api
  use iso_fortran_env, only : output_unit
  use iso_c_binding, only : c_int
  implicit none
  private

  integer, parameter, public :: GMC_API_VERSION = 1
  character(len=*), parameter, public :: GMC_UPSTREAM_BASE = &
    'bd27e348ec001e27eab3177586843e8d86f66dc8'
  character(len=*), parameter :: GMC_AISS_XTB_VERSION = '6.7.0'

  interface
    subroutine gmc_exit(status) bind(C, name='exit')
      import c_int
      integer(c_int), value :: status
    end subroutine gmc_exit
  end interface

  public :: print_gmc_capabilities

contains

  subroutine print_gmc_capabilities()
    include 'crest_metadata.fh'
    character(len=:), allocatable :: escaped_commit

    escaped_commit = json_escape(trim(commit))

    write (output_unit,'(a,i0)',advance='no') &
      '{"gmc_api_version":', GMC_API_VERSION
    write (output_unit,'(a,a,a)',advance='no') &
      ',"crest_version":"', trim(version), '","fork_commit":"'
    write (output_unit,'(a,a,a)',advance='no') &
      trim(escaped_commit), '","upstream_base":"', trim(GMC_UPSTREAM_BASE)
    write (output_unit,'(a)') &
      '","energy_components":true,"raw_energy_ranking":true,' // &
      '"qcg_single_crest_orchestration":true,"qcg_aiss_external_xtb":true,' // &
      '"qcg_aiss_xtb_validated_version":"' // GMC_AISS_XTB_VERSION // '",' // &
      '"qcg_final_optimizer":true,"qcg_final_opt_level":true,' // &
      '"qcg_final_constraints":true,"qcg_final_constraint_types":' // &
      '["distance","angle","dihedral"]}'
    flush (output_unit)
    call gmc_exit(0_c_int)
  end subroutine print_gmc_capabilities


  pure function json_escape(value) result(escaped)
    character(len=*), intent(in) :: value
    character(len=:), allocatable :: escaped
    integer :: i, pos, n

    n = len_trim(value)
    do i = 1, n
      if (iachar(value(i:i)) == 34 .or. iachar(value(i:i)) == 92) n = n + 1
    end do

    allocate (character(len=n) :: escaped)
    pos = 0
    do i = 1, len_trim(value)
      if (iachar(value(i:i)) == 34 .or. iachar(value(i:i)) == 92) then
        pos = pos + 1
        escaped(pos:pos) = achar(92)
      end if
      pos = pos + 1
      escaped(pos:pos) = value(i:i)
    end do
  end function json_escape

end module gmc_api

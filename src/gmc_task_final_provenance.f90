!================================================================================!
! GMC task-final same-source provenance sidecar.
!
! CREST owns only local opaque occurrence tokens and factual task-final status.
! GMC owns canonical source identities and cryptographic geometry identities.
!================================================================================!

module gmc_task_final_provenance
  use iso_fortran_env, only : int8, int64
  use molecule_type, only : coord
  use molecule_type_ensemble, only : rdensemble
  use gmc_provenance_format, only : gmc_extract_token, gmc_make_token, &
    & gmc_token_valid
  implicit none
  private

  character(len=*), parameter, public :: GMC_TFI_SCHEMA = &
    'glomincluster.crest.task-final-provenance.v1'
  character(len=*), parameter :: SNAPSHOT_NAME = 'gmc_task_final_normal_input.xyz'
  character(len=*), parameter :: SIDECAR_NAME = 'gmc_task_final_provenance.tsv'

  type :: provenance_record
    character(len=16) :: token = ''
    integer :: input_index = 0
    character(len=32) :: optimization_status = 'pending'
    integer :: optimized_output_index = -1
    character(len=48) :: final_selection_status = 'pending'
    integer :: final_output_index = -1
    character(len=160) :: reason = ''
  end type provenance_record

  type(provenance_record), allocatable :: records(:)
  character(len=512) :: native_input_artifact = ''
  character(len=512) :: snapshot_artifact = ''
  character(len=512) :: final_artifact = ''
  logical :: provenance_active = .false.

  public :: gmc_task_final_active
  public :: gmc_task_final_assign
  public :: gmc_task_final_begin
  public :: gmc_task_final_finalize
  public :: gmc_task_final_record_optimization

contains

  logical function gmc_task_final_active()
    gmc_task_final_active = provenance_active
  end function gmc_task_final_active

  subroutine gmc_task_final_begin(input,nall)
    character(len=*), intent(in) :: input
    integer, intent(in) :: nall
    integer :: i

    if (provenance_active) then
      error stop 'GMC task-final provenance is already active.'
    end if
    if (nall < 1) then
      error stop 'GMC task-final provenance input ensemble is empty.'
    end if

    native_input_artifact = trim(input)
    snapshot_artifact = SNAPSHOT_NAME
    final_artifact = ''
    call copy_file_bytes(trim(input),trim(snapshot_artifact))

    if (allocated(records)) deallocate (records)
    allocate (records(nall))
    do i = 1,nall
      records(i)%token = gmc_make_token(i)
      records(i)%input_index = i
      records(i)%optimization_status = 'pending'
      records(i)%optimized_output_index = -1
      records(i)%final_selection_status = 'pending'
      records(i)%final_output_index = -1
      records(i)%reason = ''
    end do
    provenance_active = .true.
    call write_sidecar()
  end subroutine gmc_task_final_begin

  subroutine gmc_task_final_assign(structures)
    type(coord), intent(inout) :: structures(:)
    integer :: i

    call require_active()
    if (.not.allocated(records)) then
      error stop 'GMC task-final provenance records are not allocated.'
    end if
    if (size(structures) /= size(records)) then
      error stop 'GMC task-final provenance input count mismatch.'
    end if
    do i = 1,size(structures)
      structures(i)%origin = records(i)%token
    end do
  end subroutine gmc_task_final_assign

  subroutine gmc_task_final_record_optimization(input_index,status,output_index)
    integer, intent(in) :: input_index
    character(len=*), intent(in) :: status
    integer, intent(in) :: output_index

    call require_active()
    if (input_index < 1 .or. input_index > size(records)) then
      error stop 'GMC task-final provenance input index is invalid.'
    end if
    records(input_index)%optimization_status = trim(status)
    records(input_index)%optimized_output_index = output_index
    if (output_index > 0) then
      records(input_index)%reason = 'optimized output occurrence recorded'
    else if (trim(status) == 'optimization_failed') then
      records(input_index)%reason = 'native optimization failed'
    else
      records(input_index)%reason = 'accepted status produced no dumped output occurrence'
    end if
  end subroutine gmc_task_final_record_optimization

  subroutine gmc_task_final_finalize(final_file)
    character(len=*), intent(in) :: final_file
    type(coord), allocatable :: structures(:)
    logical, allocatable :: seen(:)
    character(len=64) :: token
    logical :: found,malformed
    integer :: i,j,match_count

    call require_active()
    if (.not.allocated(records)) then
      error stop 'GMC task-final provenance records are not allocated.'
    end if
    final_artifact = trim(final_file)
    call rdensemble(trim(final_file),j,structures)
    if (j < 1) then
      error stop 'GMC task-final provenance final ensemble is empty.'
    end if
    allocate (seen(size(records)),source=.false.)

    do j = 1,size(structures)
      if (.not.allocated(structures(j)%origin)) then
        if (.not.allocated(structures(j)%comment)) then
          error stop 'Missing GMC task-final provenance marker in final ensemble.'
        end if
        call gmc_extract_token(structures(j)%comment,token,found,malformed)
        if (malformed) then
          error stop 'Malformed GMC task-final provenance marker in final ensemble.'
        end if
        if (.not.found) then
          error stop 'Missing GMC task-final provenance marker in final ensemble.'
        end if
      else
        token = structures(j)%origin
        found = .true.
      end if
      if (.not.found .or. .not.gmc_token_valid(token)) then
        error stop 'Invalid GMC task-final provenance token in final ensemble.'
      end if

      match_count = 0
      do i = 1,size(records)
        if (records(i)%token == token) then
          match_count = match_count + 1
          if (seen(i)) then
            error stop 'Duplicate GMC task-final provenance token in final ensemble.'
          end if
          seen(i) = .true.
          records(i)%final_selection_status = 'retained'
          records(i)%final_output_index = j
          records(i)%reason = 'retained in native tight final ensemble'
        end if
      end do
      if (match_count /= 1) then
        error stop 'Unknown GMC task-final provenance token in final ensemble.'
      end if
    end do

    do i = 1,size(records)
      if (trim(records(i)%optimization_status) == 'pending') then
        error stop 'GMC task-final provenance has an unrecorded optimization.'
      end if
      if (.not.seen(i)) then
        if (trim(records(i)%optimization_status) == 'optimization_failed') then
          records(i)%final_selection_status = 'optimization_failed'
          records(i)%reason = 'optimization failed before native final ensemble'
        else
          records(i)%final_selection_status = 'filtered'
          records(i)%reason = 'optimized/accepted but not retained after native refinement/CREGEN'
        end if
      end if
    end do
    call write_sidecar()
    provenance_active = .false.
    deallocate (seen,structures)
  end subroutine gmc_task_final_finalize

  subroutine require_active()
    if (.not.provenance_active) then
      error stop 'GMC task-final provenance is not active.'
    end if
  end subroutine require_active

  subroutine copy_file_bytes(input,output)
    character(len=*), intent(in) :: input,output
    integer(int8) :: buffer(65536)
    integer(int64) :: file_size,position,remaining
    integer :: iunit,ounit,ios,nread
    logical :: exists

    inquire (file=trim(input),exist=exists)
    if (.not.exists) error stop 'GMC task-final native input artifact does not exist.'
    open (newunit=iunit,file=trim(input),status='old',action='read', &
      & access='stream',form='unformatted',iostat=ios)
    if (ios /= 0) error stop 'Cannot open GMC task-final native input artifact.'
    inquire (unit=iunit,size=file_size)
    if (file_size <= 0_int64) then
      close (iunit)
      error stop 'GMC task-final native input artifact is empty.'
    end if
    open (newunit=ounit,file=trim(output),status='replace',action='write', &
      & access='stream',form='unformatted',iostat=ios)
    if (ios /= 0) then
      close (iunit)
      error stop 'Cannot create GMC task-final snapshot artifact.'
    end if

    position = 0_int64
    do while (position < file_size)
      remaining = file_size-position
      nread = int(min(remaining,int(size(buffer),int64)))
      read (iunit,iostat=ios) buffer(1:nread)
      if (ios /= 0) then
        close (iunit)
        close (ounit)
        error stop 'Failed reading GMC task-final native input artifact.'
      end if
      write (ounit,iostat=ios) buffer(1:nread)
      if (ios /= 0) then
        close (iunit)
        close (ounit)
        error stop 'Failed writing GMC task-final snapshot artifact.'
      end if
      position = position + int(nread,int64)
    end do
    close (iunit)
    close (ounit)
  end subroutine copy_file_bytes

  subroutine write_sidecar()
    integer :: iunit,i

    open (newunit=iunit,file=trim(SIDECAR_NAME),status='replace',action='write')
    write (iunit,'(a)') '# schema='//GMC_TFI_SCHEMA
    write (iunit,'(a)') '# native_input_artifact='//trim(native_input_artifact)
    write (iunit,'(a)') '# snapshot_artifact='//trim(snapshot_artifact)
    write (iunit,'(a)') '# final_artifact='//trim(final_artifact)
    write (iunit,'(a)') '# task_final_opt=true'
    write (iunit,'(a)') '# source_geometry_level=normal'
    write (iunit,'(a)') '# final_geometry_level=tight'
    write (iunit,'(a,i0)') '# input_count=',size(records)
    write (iunit,'(a)') 'local_token'//achar(9)//'input_index'//achar(9)// &
      & 'optimization_status'//achar(9)//'optimized_output_index'//achar(9)// &
      & 'final_selection_status'//achar(9)//'final_output_index'//achar(9)//'reason'
    do i = 1,size(records)
      write (iunit,'(a,a,i0,a,a,a,i0,a,a,a,i0,a,a)') trim(records(i)%token),achar(9), &
        & records(i)%input_index,achar(9),trim(records(i)%optimization_status), &
        & achar(9),records(i)%optimized_output_index,achar(9), &
        & trim(records(i)%final_selection_status),achar(9), &
        & records(i)%final_output_index,achar(9),trim(records(i)%reason)
    end do
    close (iunit)
  end subroutine write_sidecar

end module gmc_task_final_provenance
